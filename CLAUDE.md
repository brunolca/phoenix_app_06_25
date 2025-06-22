# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Setup and Dependencies
- `mix setup` - Install dependencies, setup database, and build assets
- `mix deps.get` - Install Elixir dependencies only

### Running the Application
- `mix phx.server` - Start Phoenix server (visit localhost:4000)
- `iex -S mix phx.server` - Start server in interactive Elixir shell

### Database Operations
- `mix ecto.create` - Create database
- `mix ecto.migrate` - Run database migrations
- `mix ecto.reset` - Drop and recreate database with seeds
- `mix run priv/repo/seeds.exs` - Run database seeds

### Testing
- `mix test` - Run all tests (automatically creates test database and runs migrations)
- `mix test test/specific_test.exs` - Run a specific test file
- `mix test test/specific_test.exs:line_number` - Run specific test by line number

### Asset Management
- `mix assets.setup` - Install Tailwind and esbuild if missing
- `mix assets.build` - Build assets for development
- `mix assets.deploy` - Build and minify assets for production

## Architecture Overview

This is a Phoenix 1.8 web application using:
- **Database**: SQLite with Ecto
- **Frontend**: Phoenix LiveView, Tailwind CSS, Heroicons
- **Server**: Bandit web server
- **Email**: Swoosh mailer
- **Telemetry**: Built-in Phoenix telemetry and LiveDashboard

### Key Application Structure
- `PhoenixApp0625.Application` - OTP application supervisor managing Repo, PubSub, Telemetry, and Endpoint
- `PhoenixApp0625Web.Endpoint` - Phoenix endpoint handling HTTP requests, WebSocket connections, and static assets
- `PhoenixApp0625Web.Router` - Route definitions with browser and API pipelines
- Database migrations auto-run in development via `Ecto.Migrator` in supervision tree

### Development Features
- Live reload for code and assets in development
- LiveDashboard available at `/dev/dashboard` in development
- Swoosh mailbox preview at `/dev/mailbox` in development
- Phoenix LiveView for real-time UI updates