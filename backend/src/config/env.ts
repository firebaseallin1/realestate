/** The server's settings, checked once at startup. */
export interface Env {
  MONGODB_URI: string;
  JWT_SECRET: string;
  PORT: number;
  NODE_ENV: 'development' | 'test' | 'production';
  CORS_ORIGINS: string[];
  UPLOAD_DIR: string;
}

/**
 * Stops the server at startup with a clear message when a setting is wrong.
 * Messages never include the values, so secrets stay out of logs.
 */
export function validateEnv(raw: Record<string, unknown>): Env {
  const problems: string[] = [];
  const text = (key: string) => String(raw[key] ?? '').trim();

  const uri = text('MONGODB_URI');
  if (!uri) {
    problems.push('MONGODB_URI is missing.');
  } else if (!/^mongodb(\+srv)?:\/\//.test(uri)) {
    problems.push('MONGODB_URI must start with mongodb:// or mongodb+srv://.');
  } else if (!/^mongodb(\+srv)?:\/\/[^/]+\/[^/?]+/.test(uri)) {
    // Without a name MongoDB silently writes to a database called "test".
    problems.push('MONGODB_URI must name the database, e.g. .../kaira_dev?retryWrites=true');
  }

  const secret = text('JWT_SECRET');
  if (secret.length < 32) {
    problems.push('JWT_SECRET must be at least 32 characters. See .env.example to generate one.');
  }

  const nodeEnv = text('NODE_ENV') || 'development';
  if (!['development', 'test', 'production'].includes(nodeEnv)) {
    problems.push('NODE_ENV must be development, test or production.');
  }

  const port = Number(text('PORT') || 1001);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    problems.push('PORT must be a valid port number.');
  }

  const corsOrigins = text('CORS_ORIGINS')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
  if (nodeEnv === 'production' && corsOrigins.length === 0) {
    problems.push('CORS_ORIGINS must list the web app address in production.');
  }

  if (problems.length > 0) {
    throw new Error(`Server settings are not valid:\n- ${problems.join('\n- ')}`);
  }

  return {
    MONGODB_URI: uri,
    JWT_SECRET: secret,
    PORT: port,
    NODE_ENV: nodeEnv as Env['NODE_ENV'],
    CORS_ORIGINS: corsOrigins,
    UPLOAD_DIR: text('UPLOAD_DIR') || 'uploads',
  };
}
