package DNSQuery::Interactive;
use strict;
use warnings;
use Term::ReadLine;

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
    
    if (exists $self->{config}{$key}) {
        $self->{config}{$key} = $value;
        print "Set $key = $value\n";
    } else {
        print "Unknown setting: $key\n";
    }
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
    
    my ($domain, $type) = split(/\s+/, $input);
    return unless $domain;
    
    $type = uc($type) if $type;
    my $result = $self->{resolver}->query($domain, $type);
    
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
