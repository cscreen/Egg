const express = require('express');
const { google } = require('googleapis');
const bodyParser = require('body-parser');
const path = require('path');

// Initialize the express application
const app = express();
app.use(bodyParser.json());

// TODO: Set to client ID and API key from the Developer Console
const CLIENT_ID = process.env.CLIENT_ID;
const CLIENT_SECRET = process.env.CLIENT_SECRET;
const REDIRECT_URI = process.env.REDIRECT_URI;
const API_KEY = process.env.API_KEY;
const CAL_ID = process.env.CAL_ID;

// Discovery doc URL for APIs used by the quickstart
const DISCOVERY_DOC = 'https://www.googleapis.com/discovery/v1/apis/calendar/v3/rest';

// Authorization scopes required by the API; multiple scopes can be
// included, separated by spaces.
const SCOPES = ['https://www.googleapis.com/auth/calendar'];

const oAuth2Client = new google.auth.OAuth2(
  CLIENT_ID,
  CLIENT_SECRET,
  REDIRECT_URI
);

// Set yesterdays date
const yesterday = new Date();
yesterday.setDate(yesterday.getDate() - 1);
yesterday.setHours(0, 0, 0);

const start = "2024-03-02";
const end = new Date().toISOString().split('T')[0];
const daysSince = (new Date(end) - new Date(start)) / (1000 * 3600 * 24);

let currEggCount = 0;

app.use(express.static("public"));

// ROUTES
app.get("/", (req, res) => {
    res.sendFile("index.html", {root: ""});
})

// Route to add new eggs
app.post('/eggs', async (req, res) => {
  const { eggsToAdd } = req.body;
  try {
    const message = await addNewEggs(oAuth2Client, eggsToAdd);
    res.send(message);
  } catch (err) {
    res.status(500).send(err.message);
  }
});

// Route to get egg data
app.get('/eggs', async (req, res) => {
  try {
    const eggData = await getCurrentEggData(oAuth2Client);
    res.json(eggData);
  } catch (err) {
    res.status(500).send(err.message);
  }
});

// Route to handle OAuth2 callback
app.get('/auth/callback', async (req, res) => {
  const code = req.query.code;
  const { tokens } = await oAuth2Client.getToken(code);
  oAuth2Client.setCredentials(tokens);
  res.send('Authentication successful! You can close this tab.');
});

// Route to initiate authentication
app.get('/auth', (req, res) => {
  const authUrl = oAuth2Client.generateAuthUrl({
    access_type: 'offline',
    scope: SCOPES,
  });
  res.redirect(authUrl);
});

// Function to get current egg data
async function getCurrentEggData(auth) {
  const calendar = google.calendar({ version: 'v3', auth });
  try {
    const response = await calendar.events.list({
      calendarId: CAL_ID,
      timeMin: yesterday.toISOString(),
      timeMax: new Date().toISOString(),
      showDeleted: false,
      singleEvents: true,
      maxResults: 15,
    });

    const events = response.data.items;
    if (!events || events.length === 0) {
      return 'No events found.';
    }

    let currCount = 0;
    events.forEach(item => {
      if (item.summary.includes('\uD83E\uDD5A')) {
        let curr = item.summary.replace('\uD83E\uDD5A', '');
        if (currCount < curr) {
          currCount = curr;
        }
      }
    });
    currEggCount = currCount;

    const daily = currEggCount / daysSince;
    const weekly = currEggCount / (daysSince / 7);
    const monthly = currEggCount / (daysSince / 30);

    return {
      dailyAvg: daily.toFixed(2),
      weeklyAvg: weekly.toFixed(2),
      monthlyAvg: monthly.toFixed(2),
      totalEggs: currEggCount,
    };
  } catch (err) {
    console.error(err.message);
    throw new Error('Error fetching events.');
  }
}

// Function to add new eggs
async function addNewEggs(auth, eggsToAdd) {
  const calendar = google.calendar({ version: 'v3', auth });
  const titleBase = '\uD83E\uDD5A';

  if (Number(eggsToAdd) > 10) {
    return 'No way. Try again';
  }

  for (let index = 1; index <= eggsToAdd; index++) {
    let title = titleBase + (Number(currEggCount) + index);
    const event = {
      summary: title,
      start: {
        date: new Date().toISOString().split('T')[0],
        timeZone: 'America/New_York',
      },
      end: {
        date: new Date().toISOString().split('T')[0],
        timeZone: 'America/New_York',
      },
      transparency: 'transparent',
    };

    try {
      await calendar.events.insert({
        calendarId: CAL_ID,
        resource: event,
      });
    } catch (err) {
      console.error(err.message);
      throw new Error('Error adding new eggs.');
    }
  }

  return `${eggsToAdd} Eggs Added`;
}


// Start the server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
