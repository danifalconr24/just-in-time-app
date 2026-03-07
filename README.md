Just in time app - JITA

App that based in a origin location and a destination location it will use Google Routes API for getting traffic information every 30 seconds in the background for the selected origin/location, and if the route 
duration increases the app will calculate how much time earlier based on route duration on real time the user will need to start traveling to arrive at the expected time the user entered when choosing origin and 
destination, with this information the app will send an urgent notification to the user. 

Design: 

Basic UI that lets the user enter the desired origin and destination locations and the time that he wants to arrive to the destination, a button in the bottom of the screen to confirm the selection.

Stack:

- Flutter 3
- Dart 3.10
- Google Routes API (https://developers.google.com/maps/documentation/routes/compute_route_matrix, https://developers.google.com/maps/documentation/routes/reference/rest/v2/TopLevel/computeRouteMatrix)

