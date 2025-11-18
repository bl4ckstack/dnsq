requires 'Net::DNS', '>= 1.0';
requires 'JSON', '>= 2.0';
requires 'Time::HiRes';
requires 'IO::Socket::INET';
requires 'Term::ReadLine';
requires 'Getopt::Long';

on 'test' => sub {
    requires 'Test::More', '>= 0.98';
};
