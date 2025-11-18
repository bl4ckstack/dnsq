.PHONY: install test clean help

help:
	@echo "dnsq - DNS Query Tool"
	@echo ""
	@echo "Available targets:"
	@echo "  make install    - Install dependencies"
	@echo "  make test       - Run tests"
	@echo "  make clean      - Clean temporary files"
	@echo "  make help       - Show this help"

install:
	cpanm --installdeps .

test:
	prove -l t/

clean:
	find . -name '*.bak' -delete
	find . -name '*~' -delete
