package DNSQuery::Resolver;
use strict;
use warnings;
use Net::DNS;
use Time::HiRes qw(time);

our $VERSION = '1.0.0';

# Valid DNS record types
my %VALID_TYPES = map { $_ => 1 } qw(
    A AAAA CNAME MX NS PTR SOA TXT SRV CAA DNSKEY DS RRSIG NSEC NSEC3 TLSA
);

sub new {
    my ($class, $config) = @_;
    
    # Validate configuration
    die "Invalid port: $config->{port}\n" 
        if $config->{port} !~ /^\d+$/ || $config->{port} < 1 || $config->{port} > 65535;
    die "Invalid timeout: $config->{timeout}\n" 
        if $config->{timeout} !~ /^\d+$/ || $config->{timeout} < 1;
    die "Invalid retries: $config->{retries}\n" 
        if $config->{retries} !~ /^\d+$/ || $config->{retries} < 0;
    
    my %resolver_opts = (
        port        => $config->{port},
        tcp_timeout => $config->{timeout},
        udp_timeout => $config->{timeout},
        retry       => $config->{retries},
        usevc       => ($config->{protocol} eq 'tcp') ? 1 : 0,
        recurse     => $config->{recurse},
        dnssec      => $config->{dnssec},
    );
    
    # Validate and set nameserver if provided
    if ($config->{server}) {
        die "Invalid server address: $config->{server}\n" 
            unless _validate_ip($config->{server}) || _validate_domain($config->{server});
        $resolver_opts{nameservers} = [$config->{server}];
    }
    
    my $resolver = Net::DNS::Resolver->new(%resolver_opts);
    
    return bless {
        resolver => $resolver,
        config   => $config,
        cache    => {},  # Simple query cache
    }, $class;
}

sub _validate_ip {
    my ($ip) = @_;
    return $ip =~ /^(\d{1,3}\.){3}\d{1,3}$/ && 
           !grep { $_ > 255 } split(/\./, $ip);
}

sub _validate_domain {
    my ($domain) = @_;
    return $domain =~ /^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$/;
}

sub query {
    my ($self, $domain, $type, $class) = @_;
    
    $type ||= $self->{config}{qtype};
    $class ||= $self->{config}{qclass};
    
    # Validate inputs
    return { error => "Invalid domain name: $domain" } 
        unless _validate_domain($domain);
    return { error => "Invalid record type: $type" } 
        unless $VALID_TYPES{uc($type)};
    
    # Check cache
    my $cache_key = "$domain:$type:$class";
    if (my $cached = $self->{cache}{$cache_key}) {
        my $age = time() - $cached->{timestamp};
        if ($age < 60) {  # Cache for 60 seconds
            return $cached->{result};
        }
    }
    
    # Query with retry and exponential backoff
    my $result = $self->_query_with_retry($domain, $type, $class);
    
    # Cache successful results
    if ($result->{packet}) {
        $self->{cache}{$cache_key} = {
            result => $result,
            timestamp => time(),
        };
        
        # Limit cache size
        if (keys %{$self->{cache}} > 100) {
            my @keys = keys %{$self->{cache}};
            delete $self->{cache}{$keys[0]};
        }
    }
    
    return $result;
}

sub _query_with_retry {
    my ($self, $domain, $type, $class) = @_;
    
    my $retries = $self->{config}{retries};
    my $backoff = 1;
    
    for my $attempt (0 .. $retries) {
        my $start_time = time();
        my $packet = eval { $self->{resolver}->send($domain, $type, $class) };
        my $query_time = int((time() - $start_time) * 1000);
        
        if ($packet) {
            return {
                packet     => $packet,
                query_time => $query_time,
                error      => undef,
                attempts   => $attempt + 1,
            };
        }
        
        # Don't sleep on last attempt
        if ($attempt < $retries) {
            select(undef, undef, undef, $backoff);
            $backoff *= 2;  # Exponential backoff
        }
    }
    
    return {
        packet     => undef,
        query_time => 0,
        error      => $self->{resolver}->errorstring || "Query failed after $retries retries",
        attempts   => $retries + 1,
    };
}

sub trace {
    my ($self, $domain) = @_;
    
    return [] unless _validate_domain($domain);
    
    my @root_servers = qw(
        198.41.0.4 199.9.14.201 192.33.4.12 199.7.91.13
        192.203.230.10 192.5.5.241 192.112.36.4 198.97.190.53
    );
    
    my @trace_results;
    my $current_server = $root_servers[0];
    my @labels = split(/\./, $domain);
    my $query_name = '';
    my $max_hops = 20;  # Prevent infinite loops
    my $hop_count = 0;
    
    for (my $i = $#labels; $i >= 0; $i--) {
        last if ++$hop_count > $max_hops;
        
        $query_name = $labels[$i] . ($query_name ? ".$query_name" : '');
        
        my $resolver = Net::DNS::Resolver->new(
            nameservers => [$current_server],
            recurse => 0,
            udp_timeout => $self->{config}{timeout},
            tcp_timeout => $self->{config}{timeout},
        );
        
        my $packet = eval { $resolver->send($query_name, 'NS') };
        
        push @trace_results, {
            server => $current_server,
            query  => $query_name,
            packet => $packet,
            error  => $packet ? undef : ($resolver->errorstring || $@),
        };
        
        last unless $packet;
        
        # Find next server from additional section first (more efficient)
        my $next_server;
        if ($i > 0) {
            foreach my $rr ($packet->additional) {
                if ($rr->type eq 'A' && $rr->can('address')) {
                    $next_server = $rr->address;
                    last;
                }
            }
            
            # Fallback: resolve NS from authority section
            unless ($next_server) {
                foreach my $rr ($packet->authority) {
                    if ($rr->type eq 'NS' && $rr->can('nsdname')) {
                        my $ns_name = $rr->nsdname;
                        my $ns_resolver = Net::DNS::Resolver->new(
                            udp_timeout => $self->{config}{timeout},
                        );
                        my $ns_packet = eval { $ns_resolver->send($ns_name, 'A') };
                        if ($ns_packet && $ns_packet->header->ancount > 0) {
                            my ($ns_rr) = $ns_packet->answer;
                            if ($ns_rr && $ns_rr->can('address')) {
                                $next_server = $ns_rr->address;
                                last;
                            }
                        }
                    }
                }
            }
            
            last unless $next_server;
            $current_server = $next_server;
        }
    }
    
    return \@trace_results;
}

1;
