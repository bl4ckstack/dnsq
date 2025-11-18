package DNSQuery::Resolver;
use strict;
use warnings;
use Net::DNS;
use Time::HiRes qw(time);

our $VERSION = '1.0.0';

sub new {
    my ($class, $config) = @_;
    
    my %resolver_opts = (
        port        => $config->{port},
        tcp_timeout => $config->{timeout},
        udp_timeout => $config->{timeout},
        retry       => $config->{retries},
        usevc       => ($config->{protocol} eq 'tcp') ? 1 : 0,
        recurse     => $config->{recurse},
        dnssec      => $config->{dnssec},
    );
    
    # Only set nameservers if explicitly provided
    $resolver_opts{nameservers} = [$config->{server}] if $config->{server};
    
    my $resolver = Net::DNS::Resolver->new(%resolver_opts);
    
    return bless {
        resolver => $resolver,
        config   => $config,
    }, $class;
}

sub query {
    my ($self, $domain, $type, $class) = @_;
    
    $type ||= $self->{config}{qtype};
    $class ||= $self->{config}{qclass};
    
    my $start_time = time();
    my $packet = $self->{resolver}->send($domain, $type, $class);
    my $query_time = int((time() - $start_time) * 1000);
    
    return {
        packet     => $packet,
        query_time => $query_time,
        error      => $packet ? undef : $self->{resolver}->errorstring,
    };
}

sub trace {
    my ($self, $domain) = @_;
    
    my @root_servers = qw(
        198.41.0.4 199.9.14.201 192.33.4.12 199.7.91.13
        192.203.230.10 192.5.5.241 192.112.36.4 198.97.190.53
    );
    
    my @trace_results;
    my $current_server = $root_servers[0];
    my @labels = split(/\./, $domain);
    my $query_name = '';
    
    for (my $i = $#labels; $i >= 0; $i--) {
        $query_name = $labels[$i] . ($query_name ? ".$query_name" : '');
        
        my $resolver = Net::DNS::Resolver->new(
            nameservers => [$current_server],
            recurse => 0,
        );
        
        my $packet = $resolver->send($query_name, 'NS');
        
        push @trace_results, {
            server => $current_server,
            query  => $query_name,
            packet => $packet,
            error  => $packet ? undef : $resolver->errorstring,
        };
        
        last unless $packet;
        
        # Find next server
        if ($i > 0) {
            foreach my $rr ($packet->additional) {
                if ($rr->type eq 'A') {
                    $current_server = $rr->address;
                    last;
                }
            }
            
            unless ($current_server) {
                foreach my $rr ($packet->authority) {
                    if ($rr->type eq 'NS') {
                        my $ns_name = $rr->nsdname;
                        my $ns_resolver = Net::DNS::Resolver->new();
                        my $ns_packet = $ns_resolver->send($ns_name, 'A');
                        if ($ns_packet && $ns_packet->header->ancount > 0) {
                            my ($ns_rr) = $ns_packet->answer;
                            $current_server = $ns_rr->address if $ns_rr->can('address');
                            last;
                        }
                    }
                }
            }
        }
    }
    
    return \@trace_results;
}

1;
