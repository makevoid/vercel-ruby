# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
This is the Vercel Ruby runtime package that enables Ruby applications to be deployed on Vercel.

## Key Project Details
- **Package**: @vercel/ruby
- **Version**: 2.1.0
- **License**: MIT
- **Repository**: vercel/vercel

## Project Structure
```
├── dist/           # Compiled JavaScript output
├── src/            # TypeScript source files
├── test/           # Test specifications
├── vc_init.rb      # Main Ruby runtime initialization script
├── package.json    # Node.js package configuration
└── tsconfig.json   # TypeScript configuration
```

## Key Components

### vc_init.rb
The main runtime initialization script that:
- Handles both Rack applications (`.ru` files) and custom handler functions
- Sets up default Rails environment variables for production
- Provides two handler methods:
  - `rack_handler`: For Rack-based applications using MockRequest
  - `webrick_handler`: For custom handlers using WEBrick server
- Entry point function: `vc__handler(event:, context:)`
- Supports base64 encoded request bodies
- Handles proper encoding for response bodies

## Supported Ruby Versions
The runtime supports Ruby versions: 3.0.x, 3.1.x, 3.2.x, 3.3.x

## Development Workflow

### Building the Project
```bash
npm run build      # Compile TypeScript to JavaScript
npm run build-ts   # Alias for build
```

### Running Tests
```bash
npm test          # Run all tests
```

### Type Checking
```bash
npm run type-check  # Check TypeScript types
```

### Development Dependencies
- TypeScript ~4.3.5
- @types/node, @types/jest
- @vercel/build-utils
- execa for process execution

## Important Implementation Details
- The entrypoint filename is replaced at runtime with `__VC_HANDLER_FILENAME`
- Rails applications default to production environment with stdout logging
- The runtime handles HTTP method, path, body, and headers from Vercel's event payload
- Rack applications are detected by `.ru` file extension
- Custom handlers must define a `Handler` constant (Proc or class)

## Notes
- The runtime sets `RAILS_ENV=production` and `RAILS_LOG_TO_STDOUT=1` by default
- Debug mode can be enabled with `VERCEL_DEBUG` environment variable
- The WEBrick handler runs on port 3000 internally