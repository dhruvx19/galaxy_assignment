"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const generate_response_1 = require("../controllers/generate_response");
const groqRouter = (0, express_1.Router)();
// Groq routes
groqRouter.post("/", generate_response_1.uploadMiddleware, generate_response_1.generateGroqResponsesController);
groqRouter.get("/history/:userId", generate_response_1.getChatHistoryController);
groqRouter.get("/history/:userId/:sessionId", generate_response_1.getChatSessionController);
// For backward compatibility, export the groqRouter as default
exports.default = groqRouter;
