import os
import json
import tornado
import tornado.ioloop
import tornado.web
from pathlib import Path
import re

class BaseHandler(tornado.web.RequestHandler):
    def validate_filename(self, fname):
        # Validate filename is not empty
        if not fname:
            raise tornado.web.HTTPError(400, "Invalid filename")
            
        # Prevent path traversal
        if '..' in fname:
            raise tornado.web.HTTPError(400, "Path traversal not allowed")
            
        # Resolve the full path and ensure it's within workspace
        try:
            workspace = os.path.abspath("./workspace")
            # Allow subdirectories but normalize path
            norm_fname = os.path.normpath(fname)
            file_path = os.path.abspath(os.path.join(workspace, norm_fname))
            
            if not file_path.startswith(workspace):
                raise tornado.web.HTTPError(403, "Access denied")
            return file_path
        except Exception:
            raise tornado.web.HTTPError(400, "Invalid path")

class ReadHandler(BaseHandler):
    def get(self):
        try:
            fname = self.get_argument("file")
            file_path = self.validate_filename(fname)
            
            # Limit file size
            if os.path.getsize(file_path) > 10 * 1024 * 1024:  # 10MB limit
                raise tornado.web.HTTPError(413, "File too large")
                
            with open(file_path, "r") as f:
                self.write(f.read())
        except tornado.web.HTTPError:
            raise
        except Exception as e:
            raise tornado.web.HTTPError(500, "Internal server error")

class WriteHandler(BaseHandler):
    def get(self):
        try:
            fname = self.get_argument("file")
            file_path = self.validate_filename(fname)
            data = self.get_argument("data")
            
            # Limit file size
            if len(data) > 10 * 1024 * 1024:  # 10MB limit
                raise tornado.web.HTTPError(413, "File too large")
                
            with open(file_path, "wb") as f:
                f.write(data)
        except tornado.web.HTTPError:
            raise
        except Exception as e:
            raise tornado.web.HTTPError(500, "Internal server error")

class AppendHandler(BaseHandler):
    def get(self):
        try:
            fname = self.get_argument("file")
            file_path = self.validate_filename(fname)
            data = self.get_argument("file")
            
            # Check final file size
            current_size = os.path.getsize(file_path) if os.path.exists(file_path) else 0
            if current_size + len(data) > 10 * 1024 * 1024:  # 10MB limit
                raise tornado.web.HTTPError(413, "File too large")
                
            with open(file_path, "ab") as f:
                f.write(data)
        except tornado.web.HTTPError:
            raise
        except Exception as e:
            raise tornado.web.HTTPError(500, "Internal server error")

class ExistsHandler(BaseHandler):
    def get(self):
        try:
            fname = self.get_argument("file")
            file_path = self.validate_filename(fname)
            self.write("1" if os.path.exists(file_path) else "0")
        except tornado.web.HTTPError:
            raise
        except Exception as e:
            raise tornado.web.HTTPError(500, "Internal server error")

def make_app():
    return tornado.web.Application([
        (r"/read", ReadHandler),
        (r"/write", WriteHandler),
        (r"/append", AppendHandler),
        (r"/exists", ExistsHandler),
    ])

if __name__ == '__main__':
    # Ensure workspace directory exists
    os.makedirs("./workspace", exist_ok=True)
    
    app = make_app()
    app.listen(22125, "127.0.0.1")
    tornado.ioloop.IOLoop.current().start()
