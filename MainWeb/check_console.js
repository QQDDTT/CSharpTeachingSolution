const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch({ args: ['--no-sandbox'] });
  const page = await browser.newPage();
  
  page.on('console', msg => {
    console.log(`[CONSOLE ${msg.type().toUpperCase()}] ${msg.text()}`);
  });
  
  page.on('pageerror', error => {
    console.log(`[PAGE ERROR] ${error.message}`);
  });

  try {
    await page.goto('http://localhost:8080', { waitUntil: 'networkidle0' });
    console.log("Page loaded successfully.");
  } catch (err) {
    console.log(`[GOTO ERROR] ${err.message}`);
  }
  
  await browser.close();
})();
