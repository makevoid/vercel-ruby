# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
This is an optimized version of the Vercel Ruby runtime that enables Ruby applications to be deployed on Vercel with significantly improved performance through streamlined Ruby implementation.

## Key Project Details
- **Type**: Optimized Ruby runtime for Vercel
- **Architecture**: Optimized Ruby handler implementation
- **Performance**: ~100ms faster cold starts vs official runtime
- **License**: MIT
- **Original**: Based on @vercel/ruby from vercel/vercel repository

## Project Structure
```
├── vc_init.rb      # Main Ruby runtime (entire implementation)
├── README.md       # Documentation
└── CLAUDE.md       # This file
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

## Key Differences from Official Runtime

### Implementation
- **Official**: Standard vc_init.rb implementation
- **Optimized**: Streamlined vc_init.rb with performance optimizations

### Performance
- Cold starts reduced by ~100ms
- More efficient request handling
- Optimized Rack application handling with MockRequest
- Minimal WEBrick usage for custom handlers

## Development Workflow

### Testing
The runtime can be tested by creating sample Rack or handler applications and invoking the `vc__handler` function directly with mock Vercel event payloads.

## Important Implementation Details
- The entrypoint filename is replaced at runtime with `__VC_HANDLER_FILENAME`
- Rails applications default to production environment with stdout logging
- The runtime handles HTTP method, path, body, and headers from Vercel's event payload
- Rack applications are detected by `.ru` file extension
- Custom handlers must define a `Handler` constant (Proc or class)
- Uses `Rack::MockRequest` for Rack apps (faster than real HTTP)
- Uses minimal WEBrick server for custom handlers
- Handles base64 encoding for binary request bodies
- Proper charset encoding handling for responses

## Optimization Techniques
1. **Direct execution** - No intermediate runtime layers
2. **MockRequest for Rack** - Avoids HTTP overhead for Rack apps
3. **Minimal dependencies** - Uses only Ruby stdlib
4. **Efficient JSON parsing** - Direct parsing of Vercel events
5. **Smart handler detection** - `.ru` extension check for Rack apps

## Notes
- The runtime sets `RAILS_ENV=production` and `RAILS_LOG_TO_STDOUT=1` by default
- Debug mode can be enabled with `VERCEL_DEBUG` environment variable
- The WEBrick handler runs on port 3000 internally (for custom handlers only)
- All signal handlers are properly cleaned up after request processing