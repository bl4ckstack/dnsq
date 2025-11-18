package DNSQuery::Batch;
use strict;
use warnings;

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
    
    open my $fh, '<', $filename or die "Cannot open batch file '$filename': $!\n";
    
    while (my $line = <$fh>) {
        chomp $line;
        $line =~ s/#.*$//;
        $line =~ s/^\s+|\s+$//g;
        next if $line eq '';
        
        my ($domain, $type) = split(/\s+/, $line);
        $type ||= $self->{config}{qtype};
        $type = uc($type);
        
        my $result = $self->{resolver}->query($domain, $type);
        
        if ($result->{error}) {
            if ($self->{config}{json}) {
                print encode_json({
                    error => $result->{error},
                    domain => $domain,
                    type => $type,
                }) . "\n";
            } else {
                print STDERR "Query failed for $domain: $result->{error}\n";
            }
            next;
        }
        
        $self->{output}->print_result($result, $domain);
        print "\n" unless $self->{config}{json} || $self->{config}{short};
    }
    
    close $fh;
}

1;
