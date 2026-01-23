FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:7.0 AS build
ARG TARGETARCH
WORKDIR /app

RUN mkdir -p src/UnityNuGet && mkdir -p src/UnityNuGet.Server && mkdir -p src/UnityNuGet.Tests

COPY src/*.sln src
COPY src/UnityNuGet/*.csproj src/UnityNuGet
COPY src/UnityNuGet.Server/*.csproj src/UnityNuGet.Server
COPY src/UnityNuGet.Tests/*.csproj src/UnityNuGet.Tests
RUN dotnet restore src -a $TARGETARCH

COPY . ./
RUN dotnet publish src -a $TARGETARCH -c Release -o /app/src/out

# Build runtime image
FROM mcr.microsoft.com/dotnet/aspnet:7.0
WORKDIR /app
COPY --from=build /app/src/out .

# Install Azure Artifacts Credential Provider for MSI authentication
RUN apt-get update && apt-get install -y wget unzip curl && \
wget -qO- https://aka.ms/install-artifacts-credprovider.sh | bash && \
apt-get clean && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /root/.nuget/NuGet
COPY ./NuGet.Config /root/.nuget/NuGet/NuGet.Config
ENTRYPOINT ["dotnet", "UnityNuGet.Server.dll"]
