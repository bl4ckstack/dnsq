# dnsq

[![Perl](https://img.shields.io/badge/Perl-5.10%2B-39457E?style=flat&logo=perl)](https://www.perl.org/)
[![License](https://img.shields.io/badge/License-MIT-00A98F?style=flat)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.0.0-FF6B6B?style=flat)](bin/dnsq)
[![DNS](https://img.shields.io/badge/DNS-Query%20Tool-4A90E2?style=flat&logo=cloudflare)](bin/dnsq)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS%20%7C%20BSD-lightgrey?style=flat)](bin/dnsq)
[![PRs Welcome](https://img.shields.io/badge/PRs-Welcome-brightgreen?style=flat)](https://github.com)

> A powerful dig-like DNS query tool with JSON output, trace mode, and batch processing — all in pure Perl.

## Features

 **Multiple Formats** • Full dig-like, short, or JSON output  
 **Protocol Agnostic** • TCP and UDP support  
 **Flexible Queries** • Custom DNS servers, ports, timeouts, and retries  
 **Batch Processing** • Query multiple domains from files  
 **DNSSEC Ready** • Request and display DNSSEC records  
 **Trace Mode** • Follow DNS delegation from root servers  
 **Interactive Shell** • Built-in REPL for exploration

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
bin/dnsq --batch example/queries.txt

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

