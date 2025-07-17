# api/auth.py
from typing import Optional, List
from datetime import datetime, timedelta
from jose import JWTError, jwt
from passlib.context import CryptContext
from pydantic import BaseModel
import ldap3
import os

# Configuration
SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-here")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 480

# LDAP Configuration
LDAP_SERVER = os.getenv("LDAP_SERVER", "ldap://your-domain-controller")
LDAP_DOMAIN = os.getenv("LDAP_DOMAIN", "company.local")

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

class User(BaseModel):
    username: str
    full_name: Optional[str] = None
    email: Optional[str] = None
    groups: List[str] = []
    disabled: bool = False

class UserRole(BaseModel):
    role: str
    permissions: List[str]

# Define roles and permissions
ROLES = {
    "admin": {
        "permissions": ["read", "write", "delete", "manage_users", "manage_models"]
    },
    "engineer": {
        "permissions": ["read", "write", "query_database"]
    },
    "viewer": {
        "permissions": ["read"]
    }
}

def authenticate_ldap(username: str, password: str) -> Optional[User]:
    """Authenticate user against LDAP/Active Directory"""
    
    try:
        server = ldap3.Server(LDAP_SERVER, get_info=ldap3.ALL)
        user_dn = f"{username}@{LDAP_DOMAIN}"
        
        conn = ldap3.Connection(
            server,
            user=user_dn,
            password=password,
            authentication=ldap3.NTLM
        )
        
        if conn.bind():
            # Get user groups
            conn.search(
                search_base=f"DC={LDAP_DOMAIN.split('.')[0]},DC={LDAP_DOMAIN.split('.')[1]}",
                search_filter=f"(sAMAccountName={username})",
                attributes=['memberOf', 'displayName', 'mail']
            )
            
            if conn.entries:
                entry = conn.entries[0]
                groups = [group.split(',')[0].split('=')[1] 
                         for group in entry.memberOf.values]
                
                return User(
                    username=username,
                    full_name=str(entry.displayName),
                    email=str(entry.mail),
                    groups=groups
                )
        
        return None
        
    except Exception as e:
        print(f"LDAP authentication error: {e}")
        return None

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    """Create JWT token"""
    to_encode = data.copy()
    
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    
    return encoded_jwt

def get_user_role(groups: List[str]) -> str:
    """Determine user role based on AD groups"""
    
    # Map AD groups to application roles
    if "IT-Admins" in groups or "AI-Admins" in groups:
        return "admin"
    elif "Engineers" in groups or "Technical-Staff" in groups:
        return "engineer"
    else:
        return "viewer"