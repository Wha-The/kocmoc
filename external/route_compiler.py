import json, os

def dump_directory(directory):
	dump = {}
	for file in os.listdir(directory):
		file = os.path.join(directory, file)
		if os.path.isdir(file):
			data = dump_directory(file)
		else:
			with open(file) as f:
				data = f.read()
		dump[file] = data
	return dump

output = json.dumps(dump_directory("routes"))
with open("output.json", "w") as f:
	f.write(output)
