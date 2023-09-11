# Testing Locally
This example demonstrates how to run the producer and consumer functions locally using gcloud emulators in Docker.

## Prerequisites
- [Install Docker](https://docs.docker.com/install/)
- [Install Docker Compose](https://docs.docker.com/compose/install/)

## Notes
- The producer and consumer functions should already be set to switch between using custom endpoints by specifying the `PUBSUB_EMULATOR_HOST` and `DATASTORE_EMULATOR_HOST` environment variables. If these environment variables are not set, the functions will use the default endpoints.
- The consumer function still needs to access the Cloud Natural Language API to get the sentiment score. This can be done by setting the `GOOGLE_APPLICATION_CREDENTIALS` environment variable to the location of the service account credentials file. This is required to run the consumer function locally, we will specify this in the `docker-compose.yml` file.

## Dockerfiles
We will need to create Dockerfiles for the producer and consumer functions. These will be used to build the images for the producer and consumer functions.

### Producer Dockerfile
Create a `./producer/Dockerfile` with the following contents:
```dockerfile
# Use the official .NET SDK image as the base image
FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
WORKDIR /app

# Copy the project files into the container
COPY Producer.csproj .
RUN dotnet restore

# Copy the rest of the application code
COPY . .

# Build the application
RUN dotnet publish -c Release -o out

# Final image
FROM mcr.microsoft.com/dotnet/aspnet:6.0
WORKDIR /app
COPY --from=build /app/out .

# Run the application
CMD ["dotnet", "Producer.dll"]
```

### Consumer Dockerfile
Create a `./consumer/Dockerfile` with the following contents:
```dockerfile
# Use the official .NET SDK image as the base image
FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
WORKDIR /app

# Copy the project files into the container
COPY Consumer.csproj .
RUN dotnet restore

# Copy the rest of the application code
COPY . .

# Build the application
RUN dotnet publish -c Release -o out

# Final image
FROM mcr.microsoft.com/dotnet/aspnet:6.0
WORKDIR /app
COPY --from=build /app/out .

# Run the application
CMD ["dotnet", "Consumer.dll"]
```

## Docker Compose
Create a `docker-compose.yml` file in the root directory with the following contents:
```yaml
version: '3'
services:
  pubsub-emulator:
    image: google/cloud-sdk:emulators
    ports:
      - "8085:8085"
    environment:
      - PUBSUB_PROJECT_ID=sentimental-analysis
    command: gcloud beta emulators pubsub start --project=sentimental-analysis --host-port=0.0.0.0:8085
  
  datastore-emulator:
    image: google/cloud-sdk:emulators
    ports:
      - "8432:8432"
    environment:
      - DATASTORE_PROJECT_ID=sentimental-analysis 
    command: gcloud beta emulators datastore start --project=sentimental-analysis --host-port=0.0.0.0:8432

  producer-app:
    build:
      context: ./producer
      dockerfile: Dockerfile
    ports:
      - "8086:8080"
    environment:
      - OUTPUT_TOPIC_ID=sentimental-analysis
      - PROJECT_ID=sentimental-analysis
      - PUBSUB_EMULATOR_HOST=pubsub-emulator:8085

  consumer-app:
    build:
      context: ./consumer
      dockerfile: Dockerfile
    ports:
      - "8087:8080"
    environment:
      - PROJECT_ID=sentimental-analysis
      - DATASTORE_EMULATOR_HOST=datastore-emulator:8432
            - GOOGLE_APPLICATION_CREDENTIALS=/tmp/keys/credentials.json
    volumes:
      - ~/.config/gcloud/application_default_credentials.json:/tmp/keys/credentials.json
```
Note: The `GOOGLE_APPLICATION_CREDENTIALS` environment variable is used to specify the location of the service account credentials file. This is required to run the consumer function locally since we still need to call the Cloud Natural Language API. 

This docker compose file will start the Pub/Sub and Datastore emulators, the producer function, and the consumer function. The producer and consumer functions will be able to communicate with the emulators using the custom endpoints.

Run the following command to start the application:
```bash
docker compose up --build
```

Create the requires Pub/Sub topic and subscription:
```bash
curl -X PUT "http://localhost:8085/v1/projects/sentimental-analysis/topics/sentimental-analysis"
curl -X PUT "http://localhost:8085/v1/projects/sentimental-analysis/subscriptions/sentimental-analysis-subscription" -H "Content-Type: application/json" --data '{"topic":"projects/sentimental-analysis/topics/sentimental-analysis","pushConfig":{"pushEndpoint":"http://consumer-app:8080"}}'
```

Try testing the producer function by sending a POST request to the producer endpoint:
```bash
curl -X POST -d 'hello world' localhost:8086
curl -X POST -d 'hello good world' localhost:8086
curl -X POST -d 'hello bad world' localhost:8086
```

Check the logs of the consumer function to see the results:
```bash
Saved entity: { "partitionId": { "projectId": "sentimental-analysis" }, "path": [ { "kind": "sentiment", "id": "2" } ] }
Sentiment score: 0.3
Sentiment weight: 0.3
Text: hello world
...
Saved entity: { "partitionId": { "projectId": "sentimental-analysis" }, "path": [ { "kind": "sentiment", "id": "3" } ] }
Commit timestamp: 
Sentiment score: 0.8
Sentiment weight: 0.8
Text: hello good world
...
Saved entity: { "partitionId": { "projectId": "sentimental-analysis" }, "path": [ { "kind": "sentiment", "id": "4" } ] }
Commit timestamp: 
Sentiment score: -0.6
Sentiment weight: 0.6
Text: hello bad world
```
Note: We could also check the datastore emulator to see the results but it is easier to check the logs.

