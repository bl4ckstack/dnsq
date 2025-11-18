package DNSQuery::Batch;
use strict;
use warnings;
use JSON;

our $VERSION = '1.0.0';

sub new {
    my ($class, $config, $resolver, $output) = @_;
    return bless {
        config   => $config,
        resolver => $resolver,
        output   => $output,
    }, $class;
}

sub process_file {
    my ($self, $filename) = @_;
    
    # Validate file exists and is readable
    unless (-f $filename && -r $filename) {
        die "Cannot access batch file '$filename': $!\n";
    }
    
    # Check file size to prevent memory issues
    my $file_size = -s $filename;
    if ($file_size > 10_000_000) {  # 10MB limit
        warn "Warning: Large batch file ($file_size bytes), processing may be slow\n";
    }
    
    open my $fh, '<', $filename or die "Cannot open batch file '$filename': $!\n";
    
    my @queries;
    my $line_num = 0;
    
    # Parse all queries first
    while (my $line = <$fh>) {
        $line_num++;
        chomp $line;
        
        # Remove comments and trim whitespace
        $line =~ s/#.*$//;
        $line =~ s/^\s+|\s+$//g;
        next if $line eq '';
        
        my ($domain, $type) = split(/\s+/, $line, 2);
        
        unless ($domain) {
            warn "Warning: Empty domain at line $line_num, skipping\n";
            next;
        }
        
        $type ||= $self->{config}{qtype};
        $type = uc($type);
        
        push @queries, {
            domain => $domain,
            type => $type,
            line => $line_num,
        };
    }
    
    close $fh;
    
    # Process queries
    my $total = scalar @queries;
    my $processed = 0;
    my $failed = 0;
    
    foreach my $query (@queries) {
        $processed++;
        
        my $result = $self->{resolver}->query($query->{domain}, $query->{type});
        
        if ($result->{error}) {
            $failed++;
            if ($self->{config}{json}) {
                print encode_json({
                    error => $result->{error},
                    domain => $query->{domain},
                    type => $query->{type},
                    line => $query->{line},
                }) . "\n";
            } else {
                print STDERR "Query failed for $query->{domain} (line $query->{line}): $result->{error}\n";
            }
            next;
        }
        
        $self->{output}->print_result($result, $query->{domain});
        print "\n" unless $self->{config}{json} || $self->{config}{short};
    }
    
    # Print summary to STDERR so it doesn't interfere with output
    unless ($self->{config}{json}) {
        print STDERR "\n;; Batch processing complete: $processed queries, $failed failed\n";
    }
}

1;
