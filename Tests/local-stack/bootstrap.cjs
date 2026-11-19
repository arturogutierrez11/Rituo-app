// Test-only entry point: starts the actual Core API module on loopback.
const path = require('node:path');
const { NestFactory } = require('@nestjs/core');
const { AppModule } = require(path.join(process.env.LOCAL_BUILD, 'app/modules/app.module.js'));
if (process.env.SERVICE_NAME !== 'rituo-isolated-local-test' ||
    !process.env.DATABASE_URL.includes('host=%2Fprivate%2Ftmp%2Frituo-local-stack-')) {
  throw new Error('Refusing non-isolated database configuration');
}
(async () => {
  const app = await NestFactory.create(AppModule);
  await app.listen(3000, '127.0.0.1');
})().catch(error => { console.error(error); process.exit(1); });
