import express from "express";
import dotenv from "dotenv";
import { exec } from "child_process";
import fs from "fs";
import path from "path";

dotenv.config();

const app = express();
app.use(express.static("screenshots"));
const PORT = 3000;
const screenshotsDir = "./screenshots";
let is_claiming = false;
let lastRewardStatus = null;
app.get("/", (req, res) => {
  res.json({ message: "Hello World" });
});
app.get("/claim", (req, res) => {
  if (is_claiming) {
    return res
      .status(429)
      .json({ error: "A claim process is already running." });
  }
  is_claiming = true;
  exec("bash ./dailyScript.sh", (error, stdout, stderr) => {
    if (error) {
      console.error(`Error: ${error.message}`);
      is_claiming = false;
      return res.status(500).json({ error: "Internal Server Error" });
    }
    if (stderr) {
      console.error(`Stderr: ${stderr}`);
      is_claiming = false;
      return res.status(500).json({ error: "Internal Server Error" });
    }
    const outputLines = stdout.trim().split("\n");
    const lastString = outputLines[outputLines.length - 1];
    is_claiming = false;
    return res.json({ result: lastString });
  });
});
app.get("/claim-full", (req, res) => {
  if (is_claiming) {
    return res
      .status(429)
      .json({ error: "A claim process is already running." });
  }
  is_claiming = true;
  exec("bash ./dailyScript.sh", (error, stdout, stderr) => {
    if (error) {
      console.error(`Error: ${error.message}`);
      is_claiming = false;
      return res.status(500).json({ error: "Internal Server Error" });
    }
    if (stderr) {
      console.error(`Stderr: ${stderr}`);
      is_claiming = false;
      return res.status(500).json({ error: "Internal Server Error" });
    }
    const outputLines = stdout.trim().split("\n");
    is_claiming = false;
    return res.json(outputLines);
  });
});
app.get("/latest", (req, res) => {
  const latestScreenshotFilename = fs
    .readdirSync(screenshotsDir)
    .map((file) => ({
      file,
      time: fs.statSync(path.join(screenshotsDir, file)).mtime.getTime(),
    }))
    .sort((a, b) => b.time - a.time) // Sort by modification time, descending
    .map(({ file }) => file)[0]; // Get the latest file
  if (!latestScreenshotFilename) {
    return res.status(404).json({ error: "No screenshots found" });
  }
  res.redirect(`./${latestScreenshotFilename}`);
});
app.get("/claim-promise", (req, res) => {
  if (is_claiming) {
    return res
      .status(429)
      .json({ error: "A claim process is already running." });
  }
  is_claiming = true;
  const claimPromise = new Promise((resolve, reject) => {
    exec("bash ./dailyScript.sh", (error, stdout, stderr) => {
      if (error) {
        console.error(`Error: ${error.message}`);
        is_claiming = false;
        lastRewardStatus = "Internal Server Error";
        return reject("Internal Server Error");
      }
      if (stderr) {
        console.error(`Stderr: ${stderr}`);
        is_claiming = false;
        lastRewardStatus = "Internal Server Error";
        return reject("Internal Server Error");
      }
      const outputLines = stdout.trim().split("\n");
      const lastString = outputLines[outputLines.length - 1];
      is_claiming = false;
      lastRewardStatus = lastString;
      return resolve(lastString);
    });
  });

  claimPromise
    .then((result) => {
      console.log(`Claim process completed: ${result}`);
    })
    .catch((err) => {
      console.error(`Claim process failed: ${err}`);
    });

  return res.json({ message: "Claim process started." });
});

app.get("/claim-status", (req, res) => {
  return res.json({
    is_claiming,
    lastRewardStatus,
  });
});
app.listen(3000, async () => {
  console.log("Server is running on http://localhost:" + PORT);
  console.log("TB_USER: " + process.env.TB_USERNAME);
  const response = await fetch("https://api.ipify.org?format=json");
  const data = await response.json();
  const publicIP = data.ip;
  console.log("Public IP: " + publicIP);
});
