#!/bin/bash

#  zipItUp.sh
#  XML Splitter
#
#  Created by Dan Loewenherz on 9/22/18.
#  Copyright © 2018 Lionheart Software LLC. All rights reserved.

ls *.xml | xargs -I {} zip "{}.zip" {}
rm *.xml
rm -rf apple_health_export
rm zipItUp.sh
