import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { getAuth, DecodedIdToken } from 'firebase-admin/auth';
import { Request } from 'express';
import Strategy from 'passport-custom';

export const FIREBASE_STRATEGY_NAME = 'firebase-jwt';

@Injectable()
export class FirebaseStrategy extends PassportStrategy(
  Strategy,
  FIREBASE_STRATEGY_NAME,
) {
  constructor() {
    super();
  }

  async validate(req: Request): Promise<DecodedIdToken> {
    const authHeader = req.headers.authorization ?? '';
    if (!authHeader.startsWith('Bearer ')) {
      throw new UnauthorizedException(
        'Missing or invalid Authorization header',
      );
    }

    const token = authHeader.slice(7);
    try {
      return await getAuth().verifyIdToken(token);
    } catch {
      throw new UnauthorizedException('Invalid Firebase token');
    }
  }
}
