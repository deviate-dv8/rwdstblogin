import express from "express";
import dotenv from "dotenv";
import { exec } from "child_process";

dotenv.config();

const app = express();
const PORT = 3000;

app.get("/", (req, res) => {
  res.json({ message: "Hello World" });
});
app.get("/claim", (req, res) => {
  exec("bash ./dailyScript.sh", (error, stdout, stderr) => {
    if (error) {
      console.error(`Error: ${error.message}`);
      return res.status(500).json({ error: "Internal Server Error" });
    }
    if (stderr) {
      console.error(`Stderr: ${stderr}`);
      return res.status(500).json({ error: "Internal Server Error" });
    }
    const outputLines = stdout.trim().split("\n");
    const lastString = outputLines[outputLines.length - 1];
    return res.json({ result: lastString });
  });
});
app.get("/claim-full", (req, res) => {
  exec("bash ./dailyScript.sh", (error, stdout, stderr) => {
    if (error) {
      console.error(`Error: ${error.message}`);
      return res.status(500).json({ error: "Internal Server Error" });
    }
    if (stderr) {
      console.error(`Stderr: ${stderr}`);
      return res.status(500).json({ error: "Internal Server Error" });
    }
    const outputLines = stdout.trim().split("\n");
    return res.json(outputLines);
  });
});
app.listen(3000, () => {
  console.log("Server is running on http://localhost:" + PORT);
  console.log("TB_USER: " + process.env.TB_USERNAME);
});
