import os
import json
import tornado
import tornado.ioloop
import tornado.web
os.chdir(os.path.dirname(os.path.abspath(__file__)))
class ReadHandler(tornado.web.RequestHandler):
	def get(self):
		fname = self.get_argument("file")
		if ".." in fname: return
		with open(os.path.join("./workspace", fname), "r") as f:
			self.write(f.read())
class WriteHandler(tornado.web.RequestHandler):
	def post(self):
		fname = self.get_argument("file")
		data = self.request.body
		if ".." in fname: return
		with open(os.path.join("./workspace", fname), "wb") as f:
			f.write(data)
class AppendHandler(tornado.web.RequestHandler):
	def post(self):
		fname = self.get_argument("file")
		data = self.request.body
		if ".." in fname: return
		with open(os.path.join("./workspace", fname), "ab") as f:
			f.write(data)
class ExistsHandler(tornado.web.RequestHandler):
	def get(self):
		fname = self.get_argument("file")
		self.write(os.path.exists(os.path.join("./workspace", fname)) and "1" or "0")
def make_app():
	return tornado.web.Application([
		(r"/read", ReadHandler),
		(r"/write", WriteHandler),
		(r"/append", AppendHandler),
		(r"/exists", ExistsHandler),
	])
if __name__ == '__main__':
	app = make_app()
	app.listen(22125, "127.0.0.1")
	tornado.ioloop.IOLoop.current().start()
