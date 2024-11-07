#!/usr/bin/env python
from __future__ import print_function

import roslib
roslib.load_manifest('rovio')
import sys
import rospy
import cv2
import numpy as np
from std_msgs.msg import String
from sensor_msgs.msg import Image, CompressedImage
from cv_bridge import CvBridge, CvBridgeError

class image_converter:

  def __init__(self):
    self.image_pub = rospy.Publisher("/cam0/image_raw", Image, queue_size=10)

    self.bridge = CvBridge()

    self.image_sub = rospy.Subscriber("/main_camera/image_raw/compressed", CompressedImage, self.callback)

  def callback(self, ros_data):
    # https://wiki.ros.org/rospy_tutorials/Tutorials/WritingImagePublisherSubscriber
    np_arr = np.frombuffer(ros_data.data, np.uint8)
    cv_image = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
    try:
      #cv_image = self.bridge.imgmsg_to_cv2(ros_data, desired_encoding="passthrough")
      #print(ros_data.header.stamp)
      cv_image = cv2.cvtColor(cv_image, cv2.COLOR_BGR2GRAY)
    except CvBridgeError as e:
      print(e)

    try:
      image_msg = self.bridge.cv2_to_imgmsg(cv_image, encoding="8UC1")
      image_msg.header.stamp = ros_data.header.stamp
      self.image_pub.publish(image_msg)
      #print("header_stamp",image_msg.header.stamp)
    except CvBridgeError as e:
      print(e)



def main(args):
  rospy.init_node('image_converter')
  ic = image_converter()
  try:
    rospy.spin()
  except KeyboardInterrupt:
    print("Shutting down")
  cv2.destroyAllWindows()

if __name__ == '__main__':
    main(sys.argv)