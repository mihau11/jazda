import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# --- Email Configuration ---
sender_email = "agent11mamrot@gmail.com"
receiver_email = ["erpniewski@gmail.com","jakub.wegrzynek@jit.team"]
receiver_id=0
password = "uzpy leqz aodq mmgf"  # Use an App Password for Gmail

# --- Email Content ---
subject = "Test Email from Python"
body = "This is a test email sent from a Python script."

# --- Construct the Email Message ---
message = MIMEMultipart()
message["From"] = sender_email
message["To"] = receiver_email[receiver_id]
message["Subject"] = subject

# Attach the body of the email as plain text
message.attach(MIMEText(body, "Elo 320"))

# --- Send the Email ---
try:
    # Connect to the SMTP server (for Gmail)
    server = smtplib.SMTP("smtp.gmail.com", 587)
    # Start a secure TLS connection
    server.starttls()
    # Log in to your email account
    server.login(sender_email, password)
    # Send the email
    text = message.as_string()
    server.sendmail(sender_email, receiver_email, text)
    print(f"Email sent successfully to {receiver_email[receiver_id]}!")
except Exception as e:
    print(f"Error: {e}")
finally:
    # Close the connection to the server
    if 'server' in locals() and server:
        server.quit()