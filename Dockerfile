# Use the official PHP image
FROM php:8.2-apache

# Copy the local code to the container
COPY . /var/www/html/

# Expose port 80
EXPOSE 80