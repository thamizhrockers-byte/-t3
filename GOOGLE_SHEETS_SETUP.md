# Google Sheets API setup

Use your existing private Google Sheet. Rename the transaction tab to `Transactions` if needed.

Headers must be exactly:
Date | Time | Transaction | Amount | TO | My Bank | Status | Category

## Apps Script

Extensions -> Apps Script. Replace Code.gs with:

const SHEET_NAME = "Transactions";
const API_TOKEN = "CHANGE_THIS_TOKEN";

function doGet(e) {
  if ((e.parameter.token || "") !== API_TOKEN) return json({success:false,error:"Unauthorized"});
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_NAME);
  if (!sheet) return json({success:false,error:"Transactions sheet not found"});
  const values = sheet.getDataRange().getValues();
  if (values.length < 2) return json([]);
  const headers = values.shift();
  return json(values.map(row => {
    const o = {};
    headers.forEach((h,i) => o[String(h)] = row[i]);
    return o;
  }));
}

function doPost(e) {
  try {
    const data = JSON.parse(e.postData.contents || "{}");
    if (data.token !== API_TOKEN) return json({success:false,error:"Unauthorized"});
    const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_NAME);
    if (!sheet) return json({success:false,error:"Transactions sheet not found"});
    sheet.appendRow([
      data.date || "",
      data.time || "",
      data.transaction || "",
      Number(data.amount || 0),
      data.to || "",
      data.bank || "",
      data.status || "",
      data.category || ""
    ]);
    return json({success:true});
  } catch(err) {
    return json({success:false,error:String(err)});
  }
}

function json(value) {
  return ContentService.createTextOutput(JSON.stringify(value))
    .setMimeType(ContentService.MimeType.JSON);
}

## Deploy

Deploy -> New deployment -> Web app.

Execute as: Me.

For this token-based prototype, the web endpoint needs to be reachable by the app, so use the available web-app access setting that permits the request to reach the script. The Sheet itself can remain private; the token is the API gate.

Copy the `/exec` URL into:
lib/config/app_config.dart

Set the SAME token in Apps Script and app_config.dart.

Then:
flutter pub get
flutter run

For release:
flutter build apk --release
