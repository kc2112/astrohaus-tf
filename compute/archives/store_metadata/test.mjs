import { handler } from './index.mjs';
import process from 'process';

// Set AWS credentials from your local profile
process.env.AWS_PROFILE = process.env.AWS_PROFILE || 'default';
process.env.AWS_REGION = 'us-east-1';

const event = {
  params: {
    querystring: {
      init: ""
    }
  },
  context: {
    stage: "main"
  }
};

const result = await handler(event);
console.log(JSON.stringify(result, null, 2));
