const express = require('express');
const path = require('path');
const app = express();
const port = 3000;

// Serve static files from frontend directory
app.use(express.static('frontend'));

// Serve index.html for the root route
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'frontend', 'index.html'));
});

app.listen(port, () => {
    console.log(`Server running at http://localhost:${port}`);
    console.log(`Press Ctrl+C to stop the server`);
}); 