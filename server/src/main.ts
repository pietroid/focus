import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { initializeFirebaseAdmin } from './firebase/firebase-admin';

async function bootstrap() {
  // Firebase Admin uses Application Default Credentials (service account
  // identity), not .env secrets. Initialize it before creating the NestJS
  // app so that any provider that calls `getFirestore()`/`getAuth()` at
  // class instantiation time finds the default app already initialized.
  initializeFirebaseAdmin();

  const app = await NestFactory.create(AppModule);

  app.enableCors({
    origin: true,
    credentials: true,
  });

  await app.listen(process.env.PORT ?? 3000);
}
void bootstrap();
