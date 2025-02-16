# Use the official Dart image
FROM dart:stable

# Set the working directory inside the container
WORKDIR /cloud_run_backend

# Copy only the pubspec files first (to leverage Docker caching)
COPY pubspec.yaml pubspec.lock ./

# Install dependencies inside the container
RUN dart pub get

# Now copy the rest of the project files
COPY . .

# Expose the port
EXPOSE 8080

# Run the Dart server
CMD ["dart", "bin/cloud_run_backend.dart"]
