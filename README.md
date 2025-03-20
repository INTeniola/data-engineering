# data-engineering
# Energy Consumption Monitoring System
## Architecture Framework Documentation

## Table of Contents
1. [Introduction](#introduction)
2. [Architecture Overview](#architecture-overview)
3. [AWS Services Selection Justification](#aws-services-selection-justification)
4. [Security Implementation](#security-implementation)
5. [Cost Optimization](#cost-optimization)
6. [Scalability and Fault Tolerance](#scalability-and-fault-tolerance)
7. [Data Batching Solution (Bonus)](#data-batching-solution)
8. [Implementation Guide](#implementation-guide)
9. [Operational Considerations](#operational-considerations)

## Introduction

This document outlines the architecture, implementation details, and operational considerations for the real-time energy consumption monitoring system. The solution is designed to capture, process, store, and provide access to energy consumption data from IoT devices installed in apartments.

### Requirements Summary

- **Cost-effectiveness:** Minimize infrastructure costs while ensuring efficiency
- **Security:** Ensure data encryption in transit and at rest
- **High Availability & Low Latency:** The system must be reliable and responsive
- **Serverless:** Leverage serverless technologies to reduce operational overhead

## Architecture Overview

The architecture implements a serverless, event-driven solution utilizing various AWS services. At a high level:

1. IoT devices send energy consumption data to AWS IoT Core
2. AWS IoT Core forwards the data to Lambda functions for processing
3. Lambda functions store data in DynamoDB (real-time access) and S3 (long-term storage)
4. API Gateway provides secure access to the processed data
5. CloudWatch monitors the entire system for errors and performance issues
6. EventBridge schedules periodic batch processing for optimization

Each component is designed to work seamlessly with others while maintaining separation of concerns for better maintainability.

## AWS Services Selection Justification

| Service | Justification |
|---------|---------------|
| **AWS IoT Core** | Provides secure communication channel for IoT devices with built-in authentication and authorization mechanisms. Supports MQTT protocol which is optimized for IoT devices with limited resources. |
| **AWS Lambda** | Serverless compute service eliminates the need for server management. Scales automatically with workload and only charges for actual compute time used, making it cost-effective. |
| **Amazon DynamoDB** | Serverless NoSQL database with single-digit millisecond response times. Pay-per-request pricing model ensures cost efficiency during varying loads. Built-in encryption at rest. |
| **Amazon S3** | Highly durable and cost-effective storage for historical data. Lifecycle policies automate transitions to lower-cost storage tiers (Standard-IA, Glacier) as data ages. |
| **Amazon API Gateway** | Provides a secure, scalable entry point for applications to access data. Supports authentication, rate limiting, and request/response transformations. |
| **AWS CloudWatch** | Comprehensive monitoring solution that enables performance tracking, error detection, and automated alerting. |
| **AWS EventBridge** | Serverless event bus service that simplifies scheduling batch processing operations. |

## Security Implementation

The solution implements multiple layers of security:

### Data in Transit
- **MQTT over TLS**: IoT devices communicate with AWS IoT Core using MQTT protocol over TLS 1.2
- **HTTPS**: API Gateway enforces HTTPS for all client communications
- **VPC Endpoints**: For enhanced security, AWS services communicate through private VPC endpoints

### Data at Rest
- **DynamoDB Encryption**: Server-side encryption enabled by default using AWS-managed keys
- **S3 Encryption**: All objects stored with AES-256 encryption
- **Lambda Environment Variables**: Encrypted using AWS KMS

### Access Control
- **IAM Roles**: Each service operates under least-privilege IAM roles
- **IoT Device Policies**: Restrict device permissions to specific topics and actions
- **API Authentication**: Optional integration with Amazon Cognito for user authentication

## Cost Optimization

The architecture is designed for cost efficiency through:

1. **Serverless Architecture**: Pay only for actual usage, not idle capacity
2. **DynamoDB On-Demand Capacity**: Scales automatically and charges only for actual reads/writes
3. **S3 Lifecycle Policies**: Automatically transitions older data to lower-cost storage tiers
4. **Data Batching**: Reduces the number of write operations to DynamoDB and S3
5. **CloudWatch Alarms**: Monitor and alert on usage patterns to catch unexpected costs early

### Estimated Cost Breakdown
| Service | Monthly Cost Estimate (USD) | Assumptions |
|---------|----------|------------|
| AWS IoT Core | $2.30 | 1,000 devices sending data every 5 minutes |
| AWS Lambda | $4.50 | 8.64M invocations per month (1,000 devices × 288 messages/day × 30 days) |
| DynamoDB | $5.00 | On-demand capacity, ~9M write requests, ~1M read requests |
| S3 | $1.50 | 10GB of data with standard storage and Glacier transitions |
| API Gateway | $3.50 | 100,000 API calls per month |
| CloudWatch | $2.00 | Basic metrics and logs |
| **Total** | **~$18.80** | Estimated monthly cost |

## Scalability and Fault Tolerance

The architecture is inherently scalable and fault-tolerant:

### Scalability
- **IoT Core**: Supports millions of connected devices
- **Lambda**: Automatically scales based on workload
- **DynamoDB**: On-demand capacity mode handles traffic spikes
- **S3**: Virtually unlimited storage capacity
- **API Gateway**: Handles thousands of concurrent requests

### Fault Tolerance
- **Multi-AZ Deployment**: Services operate across multiple Availability Zones
- **Data Replication**: DynamoDB and S3 automatically replicate data
- **Dead-Letter Queues**: Capture failed processing attempts for later analysis
- **CloudWatch Alarms**: Alert on failures and trigger automated recovery actions

## Data Batching Solution

The data batching solution optimizes performance and cost through:

1. **Scheduled Batch Processing**: EventBridge triggers Lambda functions to process data in hourly batches
2. **Data Aggregation**: Hourly aggregations (min, max, avg) reduce storage requirements
3. **Write Optimization**: Batched writes to DynamoDB reduce consumed capacity units
4. **Cost Benefits**:
   - Fewer DynamoDB write operations (up to 60x reduction)
   - Reduced S3 PUT requests
   - Lower Lambda execution time

The batching process:
1. Collects data points from the past hour
2. Groups by device ID
3. Calculates statistical aggregates
4. Stores the aggregated data in S3 in a structured format (device/date/hour)
5. Optionally updates DynamoDB with aggregated metrics

## Implementation Guide

### Prerequisites
1. AWS Account with appropriate permissions
2. Terraform installed locally
3. AWS CLI configured with appropriate credentials

### Deployment Steps
1. Clone the repository containing Terraform code
2. Update variables in `terraform.tfvars` file if needed
3. Initialize Terraform:
   ```
   terraform init
   ```
4. Review the execution plan:
   ```
   terraform plan
   ```
5. Apply the configuration:
   ```
   terraform apply
   ```
6. Note the outputs (API Gateway URL, IoT endpoint) for future reference

### Device Configuration
IoT devices should be configured with:
1. AWS IoT Core endpoint (from Terraform output)
2. Device certificates for authentication
3. MQTT topic: `{project_name}/energy/data`
4. Data format example:
   ```json
   {
     "device_id": "apt123",
     "energy_consumption": 2.5,
     "voltage": 220.4,
     "current": 11.3,
     "power_factor": 0.9,
     "temperature": 36.5
   }
   ```

## Operational Considerations

### Monitoring
- **CloudWatch Dashboards**: Create dashboards to visualize system performance
- **Alarms**: Configure alerts for critical metrics (Lambda errors, throttling, etc.)
- **Logs**: Review CloudWatch Logs for troubleshooting

### Security Maintenance
- **Certificate Rotation**: Implement a process for IoT device certificate rotation
- **IAM Policy Reviews**: Periodically review IAM policies for least privilege
- **Security Patches**: Keep Lambda function runtimes updated

### Disaster Recovery
- **Backup Strategy**: Configure regular exports of DynamoDB data
- **Recovery Process**: Document steps for disaster recovery
- **Testing**: Periodically test recovery procedures

### Maintenance Tasks
- **Data Cleanup**: Implement policies for data retention and cleanup
- **Performance Tuning**: Monitor and adjust DynamoDB throughput as needed
- **Cost Optimization**: Regularly review cost reports and optimize as necessary


Here’s a concise and structured Markdown write-up for the end of your README:

## Testing with `device-simulator.js`  

To verify the integration of AWS IoT Core, S3, and DynamoDB, I used `device-simulator.js` to publish test messages to the topic `energy-monitoring/energy/data`. The simulator sends real-time sensor data, including energy consumption, voltage, current, power factor, temperature, and a timestamp.  

### **Steps Taken for Validation**  
1. **AWS IoT Core Connection**  
   - Successfully connected to AWS IoT using certificates (`private.key`, `certificate.pem`, `rootCA.pem`).  
   - Published sample telemetry data every few seconds.  

2. **S3 Data Verification**  
   - Confirmed that incoming messages were routed correctly to S3.  
   - Ensured the S3 key structure was correctly formatted.  

3. **DynamoDB Integration Troubleshooting**  
   - Initially, no data appeared in DynamoDB, indicating a rule misconfiguration.  
   - Created an **AWS IoT Rule** with an SQL statement to extract relevant fields:
     ```sql
     SELECT *, timestamp() AS created_at FROM 'energy-monitoring/energy/data'
     ```
   - Verified that the rule correctly mapped the **partition key (`device_id`)** and stored additional attributes.  

4. **IAM Role & Permissions**  
   - Updated the IAM role to allow `dynamodb:PutItem` and `dynamodb:UpdateItem`.  
   - Ensured AWS IoT had the necessary access to write into DynamoDB.  

5. **CloudWatch Debugging**  
   - Used CloudWatch logs to identify and resolve rule execution errors.  
   - Confirmed successful writes to DynamoDB after corrections.  

### **Conclusion**  
By simulating IoT device messages, I validated the end-to-end data pipeline, ensuring that data flows correctly from **AWS IoT Core** to **S3** and **DynamoDB**. Debugging steps, including **IAM role updates**, **IoT Rule adjustments**, and **CloudWatch log analysis**, were essential in resolving integration issues. With these corrections, the system is now fully functional for real-time energy monitoring.


