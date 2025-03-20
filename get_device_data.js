exports.handler = async (event) => {
    const AWS = require('aws-sdk');
    const dynamoDB = new AWS.DynamoDB.DocumentClient();
    
    try {
        // Extract deviceId from path parameters
        const deviceId = event.pathParameters.device_id;
        
        // Get latest data for the device
        const params = {
            TableName: process.env.DYNAMODB_TABLE,
            KeyConditionExpression: "device_id = :deviceId",
            ExpressionAttributeValues: {
                ":deviceId": deviceId
            },
            ScanIndexForward: false, // Descending order (newest first)
            Limit: 10
        };
        
        const result = await dynamoDB.query(params).promise();
        
        return {
            statusCode: 200,
            headers: {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"
            },
            body: JSON.stringify(result.Items)
        };
    } catch (error) {
        console.error('Error:', error);
        return {
            statusCode: 500,
            headers: {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"
            },
            body: JSON.stringify({ message: 'Error retrieving data', error: error.message })
        };
    }
};
