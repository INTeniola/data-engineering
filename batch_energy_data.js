exports.handler = async (event) => {
    const AWS = require('aws-sdk');
    const dynamoDB = new AWS.DynamoDB.DocumentClient();
    const s3 = new AWS.S3();
    
    try {
        // Calculate time range for the last hour
        const endTime = Math.floor(Date.now() / 1000);
        const startTime = endTime - 3600; // 1 hour ago
        
        // Query DynamoDB for data from all devices in the last hour
        const scanParams = {
            TableName: process.env.DYNAMODB_TABLE,
            FilterExpression: "#ts BETWEEN :start AND :end",
            ExpressionAttributeNames: {
                "#ts": "timestamp"
            },
            ExpressionAttributeValues: {
                ":start": startTime,
                ":end": endTime
            }
        };
        
        const result = await dynamoDB.scan(scanParams).promise();
        
        // Group data by device
        const deviceData = {};
        
        for (const item of result.Items) {
            if (!deviceData[item.device_id]) {
                deviceData[item.device_id] = [];
            }
            deviceData[item.device_id].push(item);
        }
        
        // Process each device's data
        for (const [deviceId, items] of Object.entries(deviceData)) {
            // Calculate statistics
            const energyValues = items.map(item => parseFloat(item.energy_consumption));
            const stats = {
                device_id: deviceId,
                timestamp: endTime,
                hour_start: startTime,
                hour_end: endTime,
                min_energy: Math.min(...energyValues),
                max_energy: Math.max(...energyValues),
                avg_energy: energyValues.reduce((a, b) => a + b, 0) / energyValues.length,
                data_points: items.length
            };
            
            // Store aggregated data in S3
            const date = new Date(endTime * 1000);
            const year = date.getUTCFullYear();
            const month = String(date.getUTCMonth() + 1).padStart(2, '0');
            const day = String(date.getUTCDate()).padStart(2, '0');
            const hour = String(date.getUTCHours()).padStart(2, '0');
            
            const s3Key = `aggregated-data/${deviceId}/${year}/${month}/${day}/${hour}.json`;
            
            const s3Params = {
                Bucket: process.env.S3_BUCKET,
                Key: s3Key,
                Body: JSON.stringify(stats),
                ContentType: 'application/json'
            };
            
            await s3.putObject(s3Params).promise();
            
            // Optionally store aggregated data in DynamoDB
            const aggTableParams = {
                TableName: process.env.DYNAMODB_TABLE,
                Item: {
                    ...stats,
                    data_type: 'hourly_aggregate' // To distinguish from raw data
                }
            };
            
            await dynamoDB.put(aggTableParams).promise();
        }
        
        return {
            statusCode: 200,
            body: JSON.stringify({ message: 'Batch processing completed successfully' })
        };
    } catch (error) {
        console.error('Error:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({ message: 'Error in batch processing', error: error.message })
        };
    }
};
