# ==============================================================================
# PCForge Backend API - Production Multi-Stage Dockerfile
# Framework: ASP.NET Core 8.0 (C# / .NET 8)
# Target Port: 5000
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. BUILD STAGE: Restore dependencies and publish release binaries
# ------------------------------------------------------------------------------
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy project file first to leverage Docker layer caching for NuGet packages
COPY ["pc_forge_api.csproj", "./"]
RUN dotnet restore "pc_forge_api.csproj"

# Copy remaining backend source files
COPY . .

# Build and publish optimized Release bundle
RUN dotnet publish "pc_forge_api.csproj" \
    -c Release \
    -o /app/publish \
    /p:UseAppHost=false

# ------------------------------------------------------------------------------
# 2. RUNTIME STAGE: Minimal ASP.NET Core 8 runtime
# ------------------------------------------------------------------------------
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app

# Install curl for container health check probes
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

# Set runtime environment variables
ENV ASPNETCORE_URLS=http://0.0.0.0:5000 \
    ASPNETCORE_ENVIRONMENT=Production \
    DOTNET_RUNNING_IN_CONTAINER=true

# Copy published application from build stage
COPY --from=build /app/publish .

# Create wwwroot for static files and set ownership to built-in 'app' user
RUN mkdir -p /app/wwwroot && chown -R app:app /app

# Run as non-root user for container security
USER app

# Expose primary backend service port
EXPOSE 5000

# Container liveness & readiness health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Launch PCForge Web API
ENTRYPOINT ["dotnet", "pc_forge_api.dll"]
