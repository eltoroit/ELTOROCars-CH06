public with sharing class ShowProducts {
    
    public List<Product> Products { get; set; }
    public String Years { get; set; }
    public String Makes { get; set; }
    public String Families { get; set; }
    public String Passengers { get; set; }
    public String jsonCarsList {
        get {
            if (jsonCarsList == null) {
                JSONGenerator gen = JSON.createGenerator(false);
                gen.writeStartArray();
                for (Product p : Products) {
                    p.makeJson(gen);
                }
                gen.writeEndArray();
                jsonCarsList =  gen.getAsString();
            }
            return jsonCarsList;
        }
        private set;
    }
    
    public ShowProducts() {
        Years = findPicklistValues('Year__c');
        Makes = findPicklistValues('Make__c');
        Families = findPicklistValues('Family');
        Passengers = findPicklistValues('Passengers__c');
    }
    public PageReference fetchProducts() {
        // SELECT Family,Id,LocalImage__c,Make__c,Model__c,Name,Passengers__c,Year__c,HostedImageURL__c,ReviewURL__c FROM Product2 WHERE IsActive = true
        // SELECT Id,Product2.Name,UnitPrice FROM PricebookEntry WHERE IsActive = true and Pricebook2.Name = 'Standard Price Book'
        // SELECT ID, (SELECT ID FROM PriceBookEntries) FROM Product2
        // SELECT ContentType,DeveloperName,FolderId,Id,Keywords,Name,Type FROM Document WHERE IsPublic = true (+ Body?)
        
        products = new List<Product>();
        for (Product2 p2 : [SELECT Id, Name, Year__c, Make__c, Model__c, Family, Passengers__c,
                            LocalImage__c, ReviewImageURL__c, ReviewURL__c, ServerURL__c, 
                            (SELECT ID, UnitPrice 
                             FROM PriceBookEntries
                             WHERE IsActive = true 
                             AND Pricebook2.Name = 'Standard Price Book'
                            )
                            FROM Product2
                            WHERE IsActive = true
                            ORDER BY Family])
        {
            products.add(new Product(p2));
        }
        return null;
    }
    public PageReference UpdateCars() {
        List<Product2> p2s = new List<Product2>();
        for (Product p : products) {
            p2s.add(p.p2);
        }
        update p2s;
        fetchProducts();
        return null;
    }
    private String findPicklistValues(String fieldName) {
        Map<String,Schema.SObjectField> mapFields;
        Set<String> uniquePicklistValues = new Set<String>();
        mapFields = Schema.sObjectType.Product2.fields.getMap();
        Schema.DescribeFieldResult drField = mapFields.get(fieldName).getDescribe();
        for (Schema.PicklistEntry ple : drField.getPicklistValues()) {
            uniquePicklistValues.add(ple.getValue());
            System.assertEquals(ple.getValue(), ple.getLabel());
        }
        List<String> sortedPicklistValues = new List<String>();
        sortedPicklistValues.addAll(uniquePicklistValues);
        sortedPicklistValues.sort();
        return JSON.serialize(sortedPicklistValues);
    }
    public class Product {
        public String Id { get; set; }
        public Product2 p2 { get; set; }
        public Decimal Price { get; set; }
        private String OrgImage {
            get {
                OrgImage = 'servlet/servlet.ImageServer?id=';
                OrgImage += p2.LocalImage__c;
                OrgImage += '&oid=';
                OrgImage += userinfo.getOrganizationId();
                return OrgImage;
            }
            set;
        }
        public Product(Product2 p2) {
            Id = p2.Id;
            this.p2 = p2;
            Price = p2.PriceBookEntries[0].UnitPrice;
        }
        public void makeJson(JSONGenerator gen) {
            gen.writeStartObject();
            gen.writeStringField('RemoteOrgID', p2.Id);
            gen.writeStringField('Year', p2.Year__c);
            gen.writeStringField('Make', p2.Make__c);
            gen.writeStringField('Model', p2.Model__c);
            gen.writeStringField('Family', p2.Family);
            gen.writeStringField('Passengers', p2.Passengers__c);
            gen.writeStringField('ReviewURL', p2.ReviewURL__c);
            gen.writeNumberField('Price', p2.PriceBookEntries[0].UnitPrice);
            gen.writeStringField('RemoteOrgImageUrl', OrgImage);
            gen.writeStringField('ReviewImageUrl', p2.ReviewImageURL__c);
            gen.writeEndObject();
        }
    }
}