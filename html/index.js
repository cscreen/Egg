/* exported gapiLoaded */
/* exported gisLoaded */
/* exported handleAuthClick */
/* exported handleSignoutClick */

// TODO(developer): Set to client ID and API key from the Developer Console
const CLIENT_ID = '458912846644-u7g8n6jtrflqheabknijrkeqmee5g385.apps.googleusercontent.com';
const API_KEY = config.API_KEY;
const CAL_ID = '0ed0cbe93c405a650e5c2f535fae9ff8e170fc3d917b717942bd8950037dff65@group.calendar.google.com'

// Discovery doc URL for APIs used by the quickstart
const DISCOVERY_DOC = 'https://www.googleapis.com/discovery/v1/apis/calendar/v3/rest';

// Authorization scopes required by the API; multiple scopes can be
// included, separated by spaces.
const SCOPES = 'https://www.googleapis.com/auth/calendar';

let tokenClient;
let gapiInited = false;
let gisInited = false;
let currEggCount = 0;

// Set yesterdays date
var yesterday = new Date();
yesterday.setDate(yesterday.getDate() - 1);
yesterday.setHours(0, 0, 0);

const start = "2024-03-02";
const end = new Date().toISOString().split('T')[0];
var daysSince = (new Date(end) - new Date(start)) / (1000 * 3600 * 24);

/**
 * Callback after api.js is loaded.
 */
function gapiLoaded() {
  gapi.load('client', initializeGapiClient);
}

/**
 * Callback after the API client is loaded. Loads the
 * discovery doc to initialize the API.
 */
async function initializeGapiClient() {
  await gapi.client.init({
    apiKey: API_KEY,
    discoveryDocs: [DISCOVERY_DOC],
  });
  gapiInited = true;
  console.log("Google API loaded: " + gapiInited)
}

/**
 * Callback after Google Identity Services are loaded.
 */
function gisLoaded() {
  tokenClient = google.accounts.oauth2.initTokenClient({
    client_id: CLIENT_ID,
    scope: SCOPES,
    callback: '', // defined later
  });
  gisInited = true;
  console.log("Google ID loaded: " + gisInited)
}


/**
 *  Sign in the user upon button click.
 */
function handleAuth() {
  tokenClient.callback = async (resp) => {
    if (resp.error !== undefined) {
      throw (resp);
    }
    await getCurrentEggData();
  };

  if (gapi.client.getToken() === null) {
    // Prompt the user to select a Google Account and ask for consent to share their data
    // when establishing a new session.
    tokenClient.requestAccessToken({ prompt: 'consent', login_hint: 'dianepattyandothers@gmail.com' });
  } else {
    // Skip display of account chooser and consent dialog for an existing session.
    tokenClient.requestAccessToken({ prompt: '' });
  }
}


/**
 * Print the summary and start datetime/date of the next ten events in
 * the authorized user's calendar. If no events are found an
 * appropriate message is printed.
 */
async function getCurrentEggData() {
  let response;
  try {
    handleAuth()
  } catch (err) {
    console.log(err.message);
    return;
  }
  try {
    const request = {
      'calendarId': (CAL_ID).toString(),
      'timeMin': (yesterday).toISOString(),
      'timeMax': (new Date()).toISOString(),
      'showDeleted': false,
      'singleEvents': true,
      'maxResults': 15,
    };
    response = await gapi.client.calendar.events.list(request);
  } catch (err) {
    console.log(err.message);
    return;
  }

  const events = response.result.items;
  if (!events || events.length == 0) {
    document.getElementById('content').innerText = 'No events found.';
    return;
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

  var daily = currEggCount / daysSince;
  var weekly = currEggCount / (daysSince / 7);
  var monthly = currEggCount / (daysSince / 30);

  document.getElementById('dailyAvg').innerText += " " + daily.toFixed(2);
  document.getElementById('weeklyAvg').innerText += " " + weekly.toFixed(2);
  document.getElementById('monthlyAvg').innerText += " " + monthly.toFixed(2);
  document.getElementById('totalEggs').innerText += " " + currEggCount;

  await getAdvStats()
}

async function getAdvStats() {

  let start = new Date("2024-03-02");
  // Initialize an array to store the number of eggs per day
  let eggsPerDay = new Array(7).fill(0);
  try {
    const request = {
      'calendarId': (CAL_ID).toString(),
      'timeMin': (start).toISOString(),
      'showDeleted': false,
      'singleEvents': true,
      'maxResults': 2500,
    };
    response = await gapi.client.calendar.events.list(request);
  } catch (err) {
    console.log(err.message);
    return;
  }

  const statEvents = response.result.items;
  if (!statEvents || statEvents.length == 0) {
    document.getElementById('content').innerText = 'No events found.';
    return;
  }

  // Iterate over each event item
  statEvents.forEach(item => {
    let currDay = new Date(item.start.date);

    // Check if the summary contains the egg emoji
    if (item.summary.includes('\uD83E\uDD5A')) {
      switch (currDay.getDay()) {
        case 0: // Sunday
          eggsPerDay[6]++;
          break;
        case 1: // Monday
          eggsPerDay[0]++;
          break;
        case 2: // Tuesday
          eggsPerDay[1]++;
          break;
        case 3: // Wednesday
          eggsPerDay[2]++;
          break;
        case 4: // Thursday
          eggsPerDay[3]++;
          break;
        case 5: // Friday
          eggsPerDay[4]++;
          break;
        case 6: // Saturday
          eggsPerDay[5]++;
          break;
        default:
          throw new Error("something happened!!!");
      }
    }
  });

  document.getElementById("monTot").innerText += " " + eggsPerDay[0];
  document.getElementById("tueTot").innerText += " " + eggsPerDay[1];
  document.getElementById("wedTot").innerText += " " + eggsPerDay[2];
  document.getElementById("thuTot").innerText += " " + eggsPerDay[3];
  document.getElementById("friTot").innerText += " " + eggsPerDay[4];
  document.getElementById("satTot").innerText += " " + eggsPerDay[5];
  document.getElementById("sunTot").innerText += " " + eggsPerDay[6];
  document.getElementById("monAvg").innerText += " " + (eggsPerDay[0] / (daysSince / 7)).toFixed(2);
  document.getElementById("tueAvg").innerText += " " + (eggsPerDay[1] / (daysSince / 7)).toFixed(2);
  document.getElementById("wedAvg").innerText += " " + (eggsPerDay[2] / (daysSince / 7)).toFixed(2);
  document.getElementById("thuAvg").innerText += " " + (eggsPerDay[3] / (daysSince / 7)).toFixed(2);
  document.getElementById("friAvg").innerText += " " + (eggsPerDay[4] / (daysSince / 7)).toFixed(2);
  document.getElementById("satAvg").innerText += " " + (eggsPerDay[5] / (daysSince / 7)).toFixed(2);
  document.getElementById("sunAvg").innerText += " " + (eggsPerDay[6] / (daysSince / 7)).toFixed(2);

}
function addNewEggs() {

  let eggsToAdd = document.getElementById("fnewEggs").value;
  const titleBase = '\uD83E\uDD5A';
  if (Number(eggsToAdd) > 10) {
    document.getElementById('content').innerText = "No way. Try again"
  } else {
    document.getElementById('content').innerText = "Adding " + eggsToAdd + " Egg(s)"
    document.getElementById("fnewEggs").value = "";
    for (let index = 1; index <= eggsToAdd; index++) {
      var title = "";
      var newEggNum = Number(currEggCount) + index;
      title = titleBase + newEggNum;

       var event = {
          summary: title,
          start: {
            date: (new Date()).toISOString().split('T')[0],
            timeZone: "America/New_York"
          },
          end: {
            date: (new Date()).toISOString().split('T')[0],
            timeZone: "America/New_York"
          },
          transparency: "transparent"
        };
    
         var request = gapi.client.calendar.events.insert({
          calendarId: (CAL_ID).toString(),
          resource: event
        });
    
        request.execute(function (event) {
          console.log(event.htmlLink);
        });
        
        document.getElementById('content').innerText = "eggsToAdd Eggs Added"
    
    }


  }
}