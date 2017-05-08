public class DataLoader {
    public static void LoadData() {
        DataLoader dl = new DataLoader();
        
        // Web service calls
        String jsonCars = dl.findCarsJson();
        System.debug(jsonCars);
        List<Car> cars = (List<Car>) JSON.deserialize(jsonCars, List<Car>.class); 
        for (Car c : cars) {
            System.debug(c);
            c.findDocument();
        }
        
        // Clean ORG
        dl.deleteOriginalRecords();
        
        // Create Data
        dl.createData(cars);
        
        // Assign Permission sets
        assignPermissionSet();
    }
    
    @future
    public static void assignPermissionSet() {
        PermissionSet ps = [SELECT ID FROM PermissionSet WHERE name = 'ELTORO_Administrator'];
        try {
            PermissionSetAssignment psa = new PermissionSetAssignment(
                PermissionSetId = ps.Id, 
                AssigneeId = UserInfo.getUserId());
            insert psa;    
        } catch (DmlException ex) {
            if (ex.getDmlType(0) == System.StatusCode.DUPLICATE_VALUE) {
                // Do not worry about this...
            } else {
                throw ex;
            }
        }
    }
    private void createData(List<Car> cars) {
        Folder f = findFolder();
        Pricebook2 pb2 = findPricebook();
        List<Document> ds = new List<Document>();
        List<Product2> p2s = new List<Product2>();
        List<PricebookEntry> pbes = new List<PricebookEntry>();
        for (Car c : cars) {
            c.f = f;
            c.pb2 = pb2;
            p2s.add(c.createProduct());
        }
        insert p2s;
        for (Car c : cars) {
            ds.add(c.createDocument());
            pbes.add(c.createPricebookEntry());
        }
        insert ds;
        insert pbes;
        for (Car c : cars) {
            c.updateProduct();
        }
        update p2s;
    }
    private String findCarsJson() {
        HTTP h = new HTTP();
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:CarsData/');
        req.setMethod('GET');
        HTTPResponse res = h.send(req);
        return res.getBody();
    }
    private void deleteOriginalRecords() {
        List<ID> ids = new List<ID>();
        
        ids.addAll(deleteOriginalRecordsHelper('Product2'));
        ids.addAll(deleteOriginalRecordsHelper('Pricebook2'));
        ids.addAll(deleteOriginalRecordsHelper('PricebookEntry'));
        ids.addAll(deleteOriginalRecordsHelper('Opportunity'));
        ids.addAll(deleteOriginalRecordsHelper('Case'));
        ids.addAll(deleteOriginalRecordsHelper('Lead'));
        ids.addAll(deleteOriginalRecordsHelper('Contact'));
        ids.addAll(deleteOriginalRecordsHelper('Campaign'));
        ids.addAll(deleteOriginalRecordsHelper('Account'));
        ids.addAll(deleteOriginalRecordsHelper('Solution'));
        ids.addAll(deleteOriginalRecordsHelper('Document'));
        if (ids.size() > 0) {
            Database.emptyRecycleBin(ids);
        }
    }
    private Pricebook2 findPricebook() {
        Pricebook2 pb = [SELECT ID FROM Pricebook2];
        pb.IsActive = true;
        update pb;
        return pb;
    }
    private Folder findFolder() {
        return [SELECT Id, Name, DeveloperName, IsReadonly, AccessType, Type
                FROM Folder WHERE AccessType = 'public' AND IsReadonly = false AND DeveloperName = 'WebsiteImages'];
    }
    private List<ID> deleteOriginalRecordsHelper(String sObjectName) {
        List<ID> ids = new List<ID>();
        List<sObject> allRecords;
        List<sObject> undeleteRecords = new List<sObject>();
        allRecords = Database.query('SELECT IsDeleted FROM ' + sObjectName + ' ALL ROWS');
        for (sObject record : allRecords) {
            if (Boolean.valueOf(record.get('IsDeleted'))) {
                ids.add(record.Id);
            } else {
                undeleteRecords.add(record);
            }
        }
        Database.delete(undeleteRecords, false);
        return ids;
    }
    
    private class Car {
        // JSON
        public String RemoteOrgID { get; set; }
        public String Year { get; set; }
        public String Make { get; set; }
        public String Model { get; set; }
        public String Family { get; set; }
        public String Passengers { get; set; }
        public String ReviewURL { get; set; }
        public Decimal Price { get; set; }
        public String RemoteOrgImageUrl { get; set; }
        public String ReviewImageUrl { get; set; }
        
        // sObjects
        public Folder f { get; set; }
        public Product2 p2 { get; set; }
        public Document doc { get; set; }
        public Pricebook2 pb2 { get; set; }
        public PricebookEntry pbe { get; set; }
        
        public void findDocument() {
            doc = new Document();
            
            HTTP h = new HTTP();
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:CarsData/' + RemoteOrgImageUrl);
            System.debug(req.getEndpoint());
            req.setMethod('GET');
            HttpResponse resp = h.send(req);
            System.debug(resp);
            if (resp.getStatusCode() == 200) {
                doc.IsPublic = true;
                doc.body = resp.getBodyAsBlob();
                if (resp.getHeader('Content-Type') == 'image/jpeg') {
                    doc.Type = 'jpg';
                    doc.ContentType = 'image/jpeg';
                }
            }
        }
        public Product2 createProduct() {
            p2 = new Product2();
            p2.Make__c = Make;
            p2.Model__c = Model;
            p2.Year__c = Year;
            p2.Family = Family;
            p2.Passengers__c = Passengers;
            p2.ReviewURL__c = ReviewUrl;
            p2.ReviewImageURL__c = ReviewImageUrl;
            p2.Family = Family;
            p2.Name = Year + ' ' + Make + ' ' + Model;
            p2.RemoteOrgID__c = RemoteOrgID;
            p2.isActive = true;
            return p2;
        }
        public Document createDocument() {
            doc.FolderId = f.Id;
            doc.Name = 'PROD_' + p2.Id;
            doc.DeveloperName = doc.Name + '_' + Datetime.now().getTime();
            return doc;
        }
        public PricebookEntry createPricebookEntry() {
            pbe = new PricebookEntry();
            pbe.Product2Id = p2.Id;
            pbe.Pricebook2Id = pb2.Id;
            pbe.UnitPrice = Price;
            pbe.IsActive = true;
            return pbe;            
        }
        public void updateProduct() {
            p2.LocalImage__c = doc.Id;
        }
    }
}