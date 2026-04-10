class ApiError extends Error {
  constructor(message, status = 500, code = "UNKNOWN_ERROR") {
    super(message);
    this.status = status;
    this.code = code;
  }
}

module.exports = ApiError;
