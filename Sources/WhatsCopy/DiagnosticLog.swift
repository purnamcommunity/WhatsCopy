import os

private let logger = Logger(subsystem: "dev.whatscopy.WhatsCopy", category: "diag")

func diagLog(_ message: String) {
    logger.notice("\(message, privacy: .public)")
}
