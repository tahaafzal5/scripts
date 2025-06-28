#!/usr/bin/env python3

import logging
import sys
import os
import requests
import json
from datetime import datetime, timedelta, timezone
import time
import re

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('logs.txt'),
        logging.StreamHandler(sys.stdout)
    ]
)

class AutomatedSpamFilter:
    def __init__(self, tenant_id, client_id, client_secret, user_email):
        self.tenant_id = tenant_id
        self.client_id = client_id
        self.client_secret = client_secret
        self.user_email = user_email
        self.access_token = None
        self.base_url = "https://graph.microsoft.com/v1.0"
        self.processed_emails = set()  # Track processed email IDs
        
    def get_access_token(self):
        """Get access token using client credentials flow"""
        url = f"https://login.microsoftonline.com/{self.tenant_id}/oauth2/v2.0/token"
        
        data = {
            'grant_type': 'client_credentials',
            'client_id': self.client_id,
            'client_secret': self.client_secret,
            'scope': 'https://graph.microsoft.com/.default'
        }
        
        try:
            response = requests.post(url, data=data)
            response.raise_for_status()
            token_data = response.json()
            self.access_token = token_data['access_token']
            logging.info("Successfully obtained access token")
            return True
        except Exception as e:
            logging.error(f"Failed to get access token: {str(e)}")
            return False
    
    def get_headers(self):
        """Get headers with authorization"""
        return {
            'Authorization': f'Bearer {self.access_token}',
            'Content-Type': 'application/json'
        }
    
    def get_recent_emails(self, minutes_back=5, max_emails=50):
        """Get emails from inbox received in the last X minutes"""
        try:
            # Calculate time filter (emails from last X minutes)
            cutoff_time = datetime.now(timezone.utc) - timedelta(minutes=minutes_back)
            time_filter = cutoff_time.strftime('%Y-%m-%dT%H:%M:%SZ')
            
            url = f"{self.base_url}/users/{self.user_email}/mailFolders/junkemail/messages"
            params = {
                "$top": str(max_emails),
                "$select": "id,subject,sender,from,body,receivedDateTime",
                "$filter": f"receivedDateTime ge {time_filter}",
                "$orderby": "receivedDateTime desc"
            }
            
            response = requests.get(url, headers=self.get_headers(), params=params)
            response.raise_for_status()
            
            data = response.json()
            emails = data.get('value', [])
            
            # Filter out already processed emails
            new_emails = [email for email in emails if email.get('id') not in self.processed_emails]
            
            if new_emails:
                logging.info(f"Found {len(new_emails)} new emails to process")
            
            return new_emails
            
        except Exception as e:
            logging.error(f"Error retrieving recent emails: {str(e)}")
            return []
    
    def move_to_junk(self, email_id):
        """Move email to junk folder"""
        try:
            url = f"{self.base_url}/users/{self.user_email}/messages/{email_id}/move"
            data = {
                'destinationId': 'junkemail'
            }
            
            response = requests.post(url, headers=self.get_headers(), json=data)
            response.raise_for_status()
            return True
        except Exception as e:
            logging.error(f"Error moving email {email_id} to junk: {str(e)}")
            return False
    
    def delete_email(self, email_id):
        """Delete email permanently"""
        try:
            url = f"{self.base_url}/users/{self.user_email}/messages/{email_id}"
            response = requests.delete(url, headers=self.get_headers())
            response.raise_for_status()
            return True
        except Exception as e:
            logging.error(f"Error deleting email {email_id}: {str(e)}")
            return False
    
    def is_spam(self, email):
        """Advanced spam detection logic"""
        subject = email.get('subject', '').lower()
        sender_info = email.get('from', {})
        sender = sender_info.get('emailAddress', {}).get('address', '').lower() if sender_info else ''
        body_info = email.get('body', {})
        body_content = body_info.get('content', '').lower() if body_info else ''
        
        # Spam indicators with weights
        spam_score = 0
        matched_rules = []
        
        # High-risk domains (immediate spam)
        high_risk_domains = [
            'casino-winner.com', 'cryptoinvest.net', 'lotterywinners.org',
            'freemoney.biz', 'spamville.net', 'phishing-site.com',
            'fake-bank.org', 'sketchy-offers.net', 'too-good-to-be-true.com'
        ]
        
        for domain in high_risk_domains:
            if domain in sender:
                spam_score += 100  # Instant spam
                matched_rules.append(f"High-risk domain: {domain}")
                break
        
        # Subject line spam indicators
        spam_subjects = [
            'urgent', 'act now', 'limited time', 'congratulations you won',
            'claim your prize', 'winner', 'lottery', 'free money',
            'exclusive offer', 'risk free', 'guaranteed income'
        ]
        
        for phrase in spam_subjects:
            if phrase in subject:
                spam_score += 15
                matched_rules.append(f"Spam subject: {phrase}")
        
        # Body content spam indicators
        spam_keywords = [
            'casino', 'viagra', 'crypto', 'bitcoin', 'investment opportunity',
            'weight loss', 'make money fast', 'work from home', 'lose weight fast',
            'click here now', 'limited spots available'
        ]
        
        for keyword in spam_keywords:
            if keyword in body_content:
                spam_score += 10
                matched_rules.append(f"Spam keyword: {keyword}")
        
        # Suspicious patterns
        if re.search(r'\b[A-Z]{3,}\b.*\b[A-Z]{3,}\b', subject):  # Multiple uppercase words
            spam_score += 10
            matched_rules.append("Excessive caps in subject")
        
        if re.search(r'[!]{2,}', subject):  # Multiple exclamation marks
            spam_score += 5
            matched_rules.append("Multiple exclamation marks")
        
        # Check for suspicious sender patterns
        if re.search(r'\d{5,}', sender):  # Numbers in sender email
            spam_score += 5
            matched_rules.append("Numbers in sender email")
        
        # Empty or suspicious sender name
        sender_name = sender_info.get('name', '') if sender_info else ''
        if not sender_name or len(sender_name) < 3:
            spam_score += 5
            matched_rules.append("Missing or short sender name")
        
        is_spam_result = spam_score >= 20  # Threshold for spam
        
        if is_spam_result:
            logging.info(f"SPAM DETECTED (Score: {spam_score}) - Rules: {', '.join(matched_rules)}")
        
        return is_spam_result, spam_score, matched_rules
    
    def process_new_emails(self, action='move'):  # 'move' or 'delete'
        """Process new emails and handle spam"""
        if not self.access_token:
            logging.error("No access token available")
            return 0
        
        emails = self.get_recent_emails()
        processed_count = 0
        spam_count = 0
        
        for email in emails:
            try:
                email_id = email.get('id', '')
                subject = email.get('subject', '')
                sender_info = email.get('from', {})
                sender = sender_info.get('emailAddress', {}).get('address', '') if sender_info else ''
                
                # Check if it's spam
                is_spam_result, spam_score, matched_rules = self.is_spam(email)
                
                if is_spam_result:
                    if action == 'delete':
                        if self.delete_email(email_id):
                            spam_count += 1
                            logging.info(f"DELETED SPAM - From: {sender} | Subject: {subject[:50]}... | Score: {spam_score}")
                    else:  # move to junk
                        if self.move_to_junk(email_id):
                            spam_count += 1
                            logging.info(f"MOVED TO JUNK - From: {sender} | Subject: {subject[:50]}... | Score: {spam_score}")
                else:
                    logging.info(f"CLEAN EMAIL - From: {sender} | Subject: {subject[:50]}...")
                
                # Mark as processed
                self.processed_emails.add(email_id)
                processed_count += 1
                
                # Small delay to avoid rate limiting
                time.sleep(0.1)
                
            except Exception as e:
                logging.error(f"Error processing email: {str(e)}")
                continue
        
        if processed_count > 0:
            logging.info(f"Processed {processed_count} emails, {spam_count} spam detected")
        
        return spam_count
    
    def run_continuous_monitoring(self, check_interval=60, action='move'):
        """Run continuous monitoring for new emails"""
        logging.info(f"Starting continuous spam monitoring (checking every {check_interval} seconds)")
        logging.info(f"Action for spam: {action.upper()}")
        
        while True:
            try:
                # Refresh token periodically (every 50 minutes)
                if not self.access_token or (datetime.now().minute % 50 == 0):
                    if not self.get_access_token():
                        logging.error("Failed to refresh token, waiting 5 minutes...")
                        time.sleep(300)
                        continue
                
                # Process new emails
                self.process_new_emails(action)
                
                # Wait before next check
                time.sleep(check_interval)
                
            except KeyboardInterrupt:
                logging.info("Monitoring stopped by user")
                break
            except Exception as e:
                logging.error(f"Unexpected error in monitoring loop: {str(e)}")
                time.sleep(60)  # Wait a minute before retrying

def main():
    # Configuration
    TENANT_ID = os.getenv('AZURE_TENANT_ID', '')
    CLIENT_ID = os.getenv('AZURE_CLIENT_ID', '')
    CLIENT_SECRET = os.getenv('AZURE_CLIENT_SECRET', '')
    USER_EMAIL = os.getenv('HOTMAIL_EMAIL', '')
    
    # Action: 'move' to junk folder, 'delete' to delete permanently
    ACTION = os.getenv('SPAM_ACTION', 'move')  # Default to move
    
    # Check interval in seconds (default: 1 minute)
    CHECK_INTERVAL = int(os.getenv('CHECK_INTERVAL', '60'))
    
    # Validate configuration
    if not all([TENANT_ID, CLIENT_ID, CLIENT_SECRET, USER_EMAIL]):
        logging.error("Missing required environment variables:")
        logging.error("AZURE_TENANT_ID, AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, HOTMAIL_EMAIL")
        sys.exit(1)
    
    # Create filter instance
    spam_filter = AutomatedSpamFilter(TENANT_ID, CLIENT_ID, CLIENT_SECRET, USER_EMAIL)
    
    try:
        # Get initial access token
        if not spam_filter.get_access_token():
            sys.exit(1)
        
        # Start continuous monitoring
        spam_filter.run_continuous_monitoring(CHECK_INTERVAL, ACTION)
        
    except Exception as e:
        logging.error(f"Unexpected error: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()
