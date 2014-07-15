echo "Test"
curl -u ***REMOVED***:***REMOVED*** -X GET 'http://localhost:9000/v1/cap/test'
echo ""
echo "API info"
curl -u ***REMOVED***:***REMOVED*** -X GET 'http://localhost:9000/v1/cap/'
echo ""
echo "Get users"
curl -u ***REMOVED***:***REMOVED*** -X GET 'http://localhost:9000/v1/cap/users' -i
echo ""
