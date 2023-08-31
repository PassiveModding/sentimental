# Sentiment Analysis

## Description
This repository consists of demos for GCP and Terraform centered around an application designed to analyse sentiment of text.

## Features
The application consists of several serverless components that interact with each other to provide a scalable and reliable architecture.
1. Producer Function: This acts as the entry point for new data, pushing it into the processing pipeline.
2. PubSub Queue: Data is queued here before being processed, ensuring a reliable and organized flow.
3. Consumer Function: Responsible for consuming data from the queue, utilizing the Google Cloud Natural Language API for sentiment analysis, and finally storing the processed data.
4. DataStore: The processed data finds its home here, providing a repository for easy retrieval and analysis.

Both the producer and consumer functions are deployed using Google Cloud Functions, offering a scalable and serverless architecture.

![Architecture](/images/architecture.png)