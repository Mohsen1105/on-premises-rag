# api/database_connectors.py
import os
from typing import List, Dict, Any
import pyodbc
import cx_Oracle
import pandas as pd
from contextlib import contextmanager

class DatabaseConnector:
    def __init__(self):
        self.sql_server_conn_string = os.getenv("SQL_SERVER_CONN_STRING")
        self.oracle_dsn = os.getenv("ORACLE_DSN")
        self.oracle_user = os.getenv("ORACLE_USER")
        self.oracle_password = os.getenv("ORACLE_PASSWORD")
    
    @contextmanager
    def sql_server_connection(self):
        """Context manager for SQL Server connections"""
        conn = None
        try:
            conn = pyodbc.connect(self.sql_server_conn_string)
            yield conn
        finally:
            if conn:
                conn.close()
    
    @contextmanager
    def oracle_connection(self):
        """Context manager for Oracle connections"""
        conn = None
        try:
            conn = cx_Oracle.connect(
                user=self.oracle_user,
                password=self.oracle_password,
                dsn=self.oracle_dsn
            )
            yield conn
        finally:
            if conn:
                conn.close()
    
    def query_sql_server(self, query: str) -> pd.DataFrame:
        """Execute query on SQL Server and return DataFrame"""
        with self.sql_server_connection() as conn:
            return pd.read_sql(query, conn)
    
    def query_oracle(self, query: str) -> pd.DataFrame:
        """Execute query on Oracle and return DataFrame"""
        with self.oracle_connection() as conn:
            return pd.read_sql(query, conn)
    
    def get_table_schema(self, table_name: str, database: str = "sql_server") -> str:
        """Get table schema information"""
        
        if database == "sql_server":
            query = f"""
            SELECT 
                COLUMN_NAME,
                DATA_TYPE,
                CHARACTER_MAXIMUM_LENGTH,
                IS_NULLABLE
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_NAME = '{table_name}'
            ORDER BY ORDINAL_POSITION
            """
            df = self.query_sql_server(query)
        else:  # Oracle
            query = f"""
            SELECT 
                COLUMN_NAME,
                DATA_TYPE,
                DATA_LENGTH,
                NULLABLE
            FROM USER_TAB_COLUMNS
            WHERE TABLE_NAME = UPPER('{table_name}')
            ORDER BY COLUMN_ID
            """
            df = self.query_oracle(query)
        
        return df.to_string()