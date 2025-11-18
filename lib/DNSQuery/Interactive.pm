package DNSQuery::Interactive;
use strict;
use warnings;
use Term::ReadLine;
use DNSQuery::Resolver;

our $VERSION = '1.0.0';

sub new {
    my ($class, $config, $resolver, $output) = @_;
    return bless {
        config   => $config,
        resolver => $resolver,
        output   => $output,
        term     => Term::ReadLine->new('dnsq'),
    }, $class;
}

sub run {
    my ($self) = @_;
    
    print "dnsq $VERSION - Interactive DNS Query Tool\n";
    print "Type 'help' for commands, 'quit' to exit\n\n";
    
    my $prompt = "dnsq> ";
    
    while (defined(my $input = $self->{term}->readline($prompt))) {
        chomp $input;
        $input =~ s/^\s+|\s+$//g;
        next if $input eq '';
        
        $self->{term}->addhistory($input) if $input =~ /\S/;
        
        if ($input eq 'quit' || $input eq 'exit') {
            last;
        } elsif ($input eq 'help') {
            $self->print_help();
        } elsif ($input =~ /^set\s+(\w+)\s+(.+)$/) {
            $self->set_config($1, $2);
        } elsif ($input eq 'show') {
            $self->show_config();
        } else {
            $self->process_query($input);
        }
    }
    
    print "\nGoodbye!\n";
}

sub set_config {
    my ($self, $key, $value) = @_;
    
    unless (exists $self->{config}{$key}) {
        print "Unknown setting: $key\n";
        return;
    }
    
    # Validate specific settings
    if ($key eq 'port') {
        unless ($value =~ /^\d+$/ && $value >= 1 && $value <= 65535) {
            print "Error: Port must be between 1 and 65535\n";
            return;
        }
    } elsif ($key eq 'timeout') {
        unless ($value =~ /^\d+$/ && $value >= 1) {
            print "Error: Timeout must be a positive integer\n";
            return;
        }
    } elsif ($key eq 'retries') {
        unless ($value =~ /^\d+$/ && $value >= 0) {
            print "Error: Retries must be a non-negative integer\n";
            return;
        }
    } elsif ($key eq 'protocol') {
        unless ($value =~ /^(tcp|udp)$/i) {
            print "Error: Protocol must be 'tcp' or 'udp'\n";
            return;
        }
        $value = lc($value);
    }
    
    my $old_value = $self->{config}{$key};
    $self->{config}{$key} = $value;
    
    # Recreate resolver if network settings changed
    if ($key =~ /^(server|port|timeout|retries|protocol)$/) {
        eval {
            $self->{resolver} = DNSQuery::Resolver->new($self->{config});
        };
        if ($@) {
            print "Error updating resolver: $@\n";
            $self->{config}{$key} = $old_value;  # Rollback
            return;
        }
    }
    
    print "Set $key = $value\n";
}

sub show_config {
    my ($self) = @_;
    
    print "Current settings:\n";
    foreach my $key (sort keys %{$self->{config}}) {
        next if ref $self->{config}{$key};
        my $val = defined $self->{config}{$key} ? $self->{config}{$key} : 'undef';
        print "  $key = $val\n";
    }
}

sub process_query {
    my ($self, $input) = @_;
    
    my ($domain, $type) = split(/\s+/, $input, 2);
    
    unless ($domain) {
        print "Error: Domain name required\n";
        return;
    }
    
    # Validate domain format
    unless ($domain =~ /^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$/) {
        print "Error: Invalid domain name format: $domain\n";
        return;
    }
    
    $type = uc($type) if $type;
    
    my $result = eval { $self->{resolver}->query($domain, $type) };
    
    if ($@) {
        print STDERR "Query error: $@\n";
        return;
    }
    
    if ($result->{error}) {
        print STDERR "Query failed: $result->{error}\n";
        return;
    }
    
    $self->{output}->print_result($result, $domain);
}

sub print_help {
    print <<'HELP';
Interactive mode commands:
  <domain> [type]     - Query domain for specified type (default: A)
  set <key> <value>   - Set configuration option
  show                - Show current settings
  help                - Show this help
  quit/exit           - Exit interactive mode

Examples:
  google.com
  example.com MX
  set server 8.8.8.8
  set timeout 10
HELP
}

1;
