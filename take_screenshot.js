const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch();
  const page = await browser.newPage();
  await page.setViewport({ width: 1200, height: 800 });
  
  try {
    await page.goto('http://bookverse.demo', { waitUntil: 'networkidle2' });
    await page.screenshot({ 
      path: 'bookverse-homepage.png',
      fullPage: false
    });
    console.log('Screenshot saved as bookverse-homepage.png');
  } catch (error) {
    console.error('Error taking screenshot:', error.message);
  }
  
  await browser.close();
})();
