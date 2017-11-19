# Health Data Importer XML Splitter

Installation:

    wget https://github.com/lionheart/Health-XML-Splitter/releases/download/v0.1.0-alpha/splitter
    chmod +x splitter

This binary was compiled on macOS 10.13.1. Other platforms have not been tested nor are supported. Pull requests are welcome for additional support.

Usage:

    ./splitter FILENAME

Provide the path to your export.xml as the first argument and `splitter` will output the chunks in /tmp/. After the chunks are created, just zip the files up before importing. E.g.,

    ls *.xml | xargs -I {} zip "{}.zip" {}

Once the files are zipped, just provide them to Health Data Importer individually. Please [create an issue](https://github.com/lionheart/Health-XML-Splitter/issues/new) if you run into any problems at all.
