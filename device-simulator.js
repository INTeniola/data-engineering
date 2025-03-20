const awsIot = require('aws-iot-device-sdk');

const device = awsIot.device({
  keyPath: './private.key',
  certPath: './certificate.pem',
  caPath: './rootCA.pem',
  clientId: 'apt123',
  host: 'a3mxdhhk4zij59-ats.iot.us-east-1.amazonaws.com' // From Terraform output
});

device.on('connect', function() {
  console.log('Connected to AWS IoT');
  
  // Send data every 5 seconds
  setInterval(function() {
    const data = {
      device_id: 'apt123',
      energy_consumption: (Math.random() * 5).toFixed(2),
      voltage: 220 + (Math.random() * 5).toFixed(2),
      current: 10 + (Math.random() * 3).toFixed(2),
      power_factor: (0.8 + Math.random() * 0.2).toFixed(2),
      temperature: 35 + (Math.random() * 5).toFixed(2)
    };
    
    console.log('Publishing:', data);
    device.publish('energy-monitoring/energy/data', JSON.stringify(data));
  }, 5000);
});
