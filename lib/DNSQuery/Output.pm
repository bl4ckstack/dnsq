package DNSQuery::Output;
use strict;
use warnings;
use JSON;

our $VERSION = '1.0.0';

sub new {
    my ($class, $config) = @_;
    return bless { config => $config }, $class;
}

sub print_result {
    my ($self, $result, $domain) = @_;
    
    unless ($result && ref($result) eq 'HASH') {
        warn "Invalid result object\n";
        return;
    }
    
    return unless $result->{packet};
    
    eval {
        if ($self->{config}{json}) {
            $self->print_json($result, $domain);
        } elsif ($self->{config}{short}) {
            $self->print_short($result->{packet});
        } else {
            $self->print_full($result, $domain);
        }
    };
    
    if ($@) {
        warn "Error printing result: $@\n";
    }
}

sub print_full {
    my ($self, $result, $domain) = @_;
    my $packet = $result->{packet};
    my $config = $self->{config};
    
    my $header = $packet->header;
    
    # Header line
    print "\n;; $domain. $config->{qtype} $config->{qclass}\n";
    
    # Status line
    my @flags;
    push @flags, 'qr' if $header->qr;
    push @flags, 'aa' if $header->aa;
    push @flags, 'tc' if $header->tc;
    push @flags, 'rd' if $header->rd;
    push @flags, 'ra' if $header->ra;
    push @flags, 'ad' if $header->ad;
    push @flags, 'cd' if $header->cd;
    
    printf ";; status: %s, id: %d, flags: %s\n", 
        $header->rcode, $header->id, join(' ', @flags);
    printf ";; QUERY: %d, ANSWER: %d, AUTHORITY: %d, ADDITIONAL: %d\n\n",
        $header->qdcount, $header->ancount, $header->nscount, $header->arcount;
    
    # Answer section (most important)
    if ($header->ancount > 0) {
        print ";; ANSWER:\n";
        foreach my $rr ($packet->answer) {
            print $rr->string . "\n";
        }
        print "\n";
    }
    
    # Authority section (only if present and verbose)
    if ($header->nscount > 0 && $config->{verbose}) {
        print ";; AUTHORITY:\n";
        foreach my $rr ($packet->authority) {
            print $rr->string . "\n";
        }
        print "\n";
    }
    
    # Additional section (only if verbose)
    if ($header->arcount > 0 && $config->{verbose}) {
        print ";; ADDITIONAL:\n";
        foreach my $rr ($packet->additional) {
            next if $rr->type eq 'OPT';  # Skip EDNS
            print $rr->string . "\n";
        }
        print "\n";
    }
    
    # Query stats
    my $server_addr = $config->{server} || 'system';
    printf ";; Query time: %d ms | Server: %s#%d (%s) | Size: %d bytes\n\n",
        $result->{query_time}, $server_addr, $config->{port}, 
        $config->{protocol}, length($packet->data);
}

sub print_short {
    my ($self, $packet) = @_;
    
    return unless $packet;
    
    my @answers = eval { $packet->answer };
    return if $@;
    
    foreach my $rr (@answers) {
        next unless $rr;
        
        my $output = eval {
            if ($rr->can('address')) {
                return $rr->address;
            } elsif ($rr->can('cname')) {
                return $rr->cname;
            } elsif ($rr->can('exchange')) {
                return $rr->exchange;
            } elsif ($rr->can('nsdname')) {
                return $rr->nsdname;
            } elsif ($rr->can('ptrdname')) {
                return $rr->ptrdname;
            } elsif ($rr->can('txtdata')) {
                return $rr->txtdata;
            } elsif ($rr->can('rdstring')) {
                return $rr->rdstring;
            }
            return undef;
        };
        
        print "$output\n" if defined $output && !$@;
    }
}

sub print_json {
    my ($self, $result, $domain) = @_;
    my $packet = $result->{packet};
    my $config = $self->{config};
    
    my $header = $packet->header;
    my %output = (
        domain => $domain,
        type => $config->{qtype},
        class => $config->{qclass},
        status => $header->rcode,
        query_time_ms => $result->{query_time},
        server => $config->{server} || 'system-default',
        port => $config->{port},
        protocol => $config->{protocol},
        flags => {
            qr => $header->qr ? JSON::true : JSON::false,
            aa => $header->aa ? JSON::true : JSON::false,
            tc => $header->tc ? JSON::true : JSON::false,
            rd => $header->rd ? JSON::true : JSON::false,
            ra => $header->ra ? JSON::true : JSON::false,
            ad => $header->ad ? JSON::true : JSON::false,
            cd => $header->cd ? JSON::true : JSON::false,
        },
        question => [],
        answer => [],
        authority => [],
        additional => [],
    );
    
    foreach my $q ($packet->question) {
        push @{$output{question}}, {
            name => $q->qname,
            type => $q->qtype,
            class => $q->qclass,
        };
    }
    
    foreach my $rr ($packet->answer) {
        push @{$output{answer}}, $self->parse_rr($rr);
    }
    
    foreach my $rr ($packet->authority) {
        push @{$output{authority}}, $self->parse_rr($rr);
    }
    
    foreach my $rr ($packet->additional) {
        next if $rr->type eq 'OPT';  # Skip EDNS pseudo-records
        push @{$output{additional}}, $self->parse_rr($rr);
    }
    
    print encode_json(\%output) . "\n";
}

sub parse_rr {
    my ($self, $rr) = @_;
    
    return {} unless $rr;
    
    my %record = eval {
        (
            name => $rr->name,
            type => $rr->type,
            class => $rr->class,
            ttl => $rr->ttl,
        )
    };
    
    return \%record if $@;
    
    # Safely extract record-specific data
    eval {
        if ($rr->can('address')) {
            $record{address} = $rr->address;
        } elsif ($rr->can('cname')) {
            $record{cname} = $rr->cname;
        } elsif ($rr->can('exchange')) {
            $record{exchange} = $rr->exchange;
            $record{preference} = $rr->preference if $rr->can('preference');
        } elsif ($rr->can('nsdname')) {
            $record{nsdname} = $rr->nsdname;
        } elsif ($rr->can('ptrdname')) {
            $record{ptrdname} = $rr->ptrdname;
        } elsif ($rr->can('mname')) {
            $record{mname} = $rr->mname;
            $record{rname} = $rr->rname if $rr->can('rname');
            $record{serial} = $rr->serial if $rr->can('serial');
            $record{refresh} = $rr->refresh if $rr->can('refresh');
            $record{retry} = $rr->retry if $rr->can('retry');
            $record{expire} = $rr->expire if $rr->can('expire');
            $record{minimum} = $rr->minimum if $rr->can('minimum');
        } elsif ($rr->can('txtdata')) {
            $record{txtdata} = $rr->txtdata;
        } elsif ($rr->can('target')) {
            $record{target} = $rr->target;
            $record{priority} = $rr->priority if $rr->can('priority');
            $record{weight} = $rr->weight if $rr->can('weight');
            $record{port} = $rr->port if $rr->can('port');
        } elsif ($rr->can('rdstring')) {
            $record{rdata} = $rr->rdstring;
        }
    };
    
    return \%record;
}

sub print_trace {
    my ($self, $trace_results, $domain) = @_;
    
    print "; <<>> dnsq trace <<>> $domain\n";
    print ";; global options: +cmd\n\n";
    
    foreach my $result (@$trace_results) {
        print ";; Querying server: $result->{server} for $result->{query}\n";
        
        if ($result->{error}) {
            print STDERR "Query failed: $result->{error}\n";
            next;
        }
        
        my $packet = $result->{packet};
        
        if ($packet->header->ancount > 0) {
            print ";; ANSWER SECTION:\n";
            foreach my $rr ($packet->answer) {
                print $rr->string . "\n";
            }
        }
        
        if ($packet->header->nscount > 0) {
            print "\n;; AUTHORITY SECTION:\n";
            foreach my $rr ($packet->authority) {
                print $rr->string . "\n";
            }
        }
        
        if ($packet->header->arcount > 0) {
            print "\n;; ADDITIONAL SECTION:\n";
            foreach my $rr ($packet->additional) {
                print $rr->string . "\n";
            }
        }
        
        print "\n";
    }
}

1;
