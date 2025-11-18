# dnsq

[![Perl](https://img.shields.io/badge/perl-5.10+-blue.svg)](https://www.perl.org/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.0-orange.svg)](bin/dnsq)

A full-featured dig-like DNS query tool written in Perl with JSON output, TCP/UDP support, trace mode, and batch processing.

## Features

- **Multiple Output Formats**: Full dig-like, short (answers only), or JSON
- **Protocol Support**: TCP and UDP
- **Custom DNS Server**: Query any DNS server with custom port
- **Timeout & Retries**: Configurable timeout and retry settings
- **Batch Mode**: Process multiple queries from a file
- **Trace Mode**: Follow DNS delegation path from root servers
- **Interactive Mode**: Interactive shell for multiple queries
- **DNSSEC Support**: Request and display DNSSEC records

## Installation

```bash
# Install dependencies
cpanm --installdeps .

# Or using cpan
cpan Net::DNS JSON Term::ReadLine

# Make executable
chmod +x bin/dnsq
```

## Usage

```bash
# Basic query
bin/dnsq google.com

# Query specific record type
bin/dnsq google.com MX

# Use custom DNS server
bin/dnsq -s 8.8.8.8 example.com

# JSON output
bin/dnsq --json google.com

# Short output (answers only)
bin/dnsq --short google.com

# Use TCP
bin/dnsq --tcp google.com

# Trace DNS delegation
bin/dnsq --trace example.com

# Batch mode
bin/dnsq --batch examples/queries.txt

# Interactive mode
bin/dnsq --interactive
```

## Options

| Option | Description |
|--------|-------------|
| `-s, --server <ip>` | DNS server to query |
| `-p, --port <port>` | DNS server port (default: 53) |
| `-t, --timeout <sec>` | Query timeout (default: 5) |
| `-r, --retries <num>` | Number of retries (default: 3) |
| `-T, --tcp` | Use TCP protocol |
| `-j, --json` | JSON output |
| `-S, --short` | Short output (answers only) |
| `--trace` | Trace DNS delegation |
| `-b, --batch <file>` | Batch mode |
| `-i, --interactive` | Interactive mode |
| `-d, --dnssec` | Request DNSSEC |
| `-h, --help` | Show help |

## Examples

```bash
# Get all A records as JSON
bin/dnsq --json --short google.com A

# Verify DNS propagation
bin/dnsq -s 8.8.8.8 example.com      # Google DNS
bin/dnsq -s 1.1.1.1 example.com      # Cloudflare DNS

# Batch processing
bin/dnsq --batch examples/queries.txt --json > results.json

# Interactive session
bin/dnsq --interactive
dnsq> google.com
dnsq> example.com MX
dnsq> set server 8.8.8.8
dnsq> quit
```

## Project Structure

```
.
├── bin/
│   └── dnsq              # Main executable
├── lib/
│   └── DNSQuery/
│       ├── Resolver.pm   # DNS resolution logic
│       ├── Output.pm     # Output formatting
│       ├── Batch.pm      # Batch processing
│       └── Interactive.pm # Interactive mode
├── t/
│   └── basic.t           # Tests
├── examples/
│   └── queries.txt       # Sample batch file
├── cpanfile              # Dependencies
└── README.md
```

## License

MIT
