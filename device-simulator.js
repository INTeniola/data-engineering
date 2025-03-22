const awsIot = require('aws-iot-device-sdk');
const fs = require('fs');
const path = require('path');

// Check if certificate files exist
const certDir = __dirname;
const keyPath = path.join(certDir, 'private.key');
const certPath = path.join(certDir, 'certificate.pem');
const caPath = path.join(certDir, 'rootCA.pem');

// Validate certificate files exist
[keyPath, certPath, caPath].forEach(file => {
  if (!fs.existsSync(file)) {
    console.error(`ERROR: Certificate file not found: ${file}`);
    process.exit(1);
  } else {
    console.log(`Found certificate file: ${file}`);
  }
});

const device = awsIot.device({
  keyPath: keyPath,
  certPath: certPath,
  caPath: caPath,
  clientId: 'apt123',
  host: "a3mxdhhk4zij59-ats.iot.us-east-1.amazonaws.com" 
});

// Add error handling
device.on('error', function(error) {
  console.error('Connection error:', error);
});

device.on('reconnect', function() {
  console.log('Reconnecting...');
});

device.on('offline', function() {
  console.log('Device went offline');
});

device.on('connect', function() {
  console.log('Connected to AWS IoT');
  
  // Send data every 5 seconds
  setInterval(function() {
    const data = {
      device_id: 'apt123',
      energy_consumption: parseFloat((Math.random() * 5).toFixed(2)),
      voltage: parseFloat((220 + Math.random() * 5).toFixed(2)),
      current: parseFloat((10 + Math.random() * 3).toFixed(2)),
      power_factor: parseFloat((0.8 + Math.random() * 0.2).toFixed(2)),
      temperature: parseFloat((35 + Math.random() * 5).toFixed(2)),
      timestamp: Math.floor(Date.now() / 1000)
    };
    
    console.log('Publishing:', data);
    device.publish('energy-monitoring/energy/data', JSON.stringify(data));
  }, 5000);
});
