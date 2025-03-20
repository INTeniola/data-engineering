exports.handler = async (event) => {
    const AWS = require('aws-sdk');
    const dynamoDB = new AWS.DynamoDB.DocumentClient();
    const s3 = new AWS.S3();
    
    try {
        // If data comes from IoT rule, it will be in the event directly
        const data = event;
        console.log('Received data:', JSON.stringify(data));
        
        // Store in DynamoDB
        const dynamoParams = {
            TableName: process.env.DYNAMODB_TABLE,
            Item: {
                device_id: data.device_id,
                timestamp: data.timestamp || Math.floor(Date.now() / 1000),
                energy_consumption: data.energy_consumption,
                voltage: data.voltage,
                current: data.current,
                power_factor: data.power_factor,
                temperature: data.temperature
            }
        };
        
        await dynamoDB.put(dynamoParams).promise();
        
        // Store raw data in S3
        const date = new Date();
        const year = date.getUTCFullYear();
        const month = String(date.getUTCMonth() + 1).padStart(2, '0');
        const day = String(date.getUTCDate()).padStart(2, '0');
        const hour = String(date.getUTCHours()).padStart(2, '0');
        
        const s3Key = `raw-data/${data.device_id}/${year}/${month}/${day}/${hour}/${data.timestamp || Math.floor(Date.now() / 1000)}.json`;
        
        const s3Params = {
            Bucket: process.env.S3_BUCKET,
            Key: s3Key,
            Body: JSON.stringify(data),
            ContentType: 'application/json'
        };
        
        await s3.putObject(s3Params).promise();
        
        return {
            statusCode: 200,
            body: JSON.stringify({ message: 'Data processed successfully' })
        };
    } catch (error) {
        console.error('Error:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({ message: 'Error processing data', error: error.message })
        };
    }
};
