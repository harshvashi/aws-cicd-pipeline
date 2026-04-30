import app from '../index';

describe('Health Check Endpoint', () => {
  it('should have a defined app', () => {
    expect(app).toBeDefined();
  });
});

describe('Application', () => {
  it('should be a function (Express app)', () => {
    expect(typeof app).toBe('function');
  });

  it('should have required Express methods', () => {
    expect(typeof app.get).toBe('function');
    expect(typeof app.post).toBe('function');
    expect(typeof app.use).toBe('function');
  });
});
