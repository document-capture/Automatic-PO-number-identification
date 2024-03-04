codeunit 61090 "PTE CDC Find all PO numbers"
{
    TableNo = 6085590;

    trigger OnRun()
    begin
        // Process the default Full Capture codeunit first
        CODEUNIT.RUN(CODEUNIT::"CDC Purch. - Full Capture", Rec);

        FindAllPONumbersInDocument(Rec);
    end;

    local procedure FindAllPONumbersInDocument(var DCDocument: Record "CDC Document")
    var
        DocumentWord: Record "CDC Document Word";
        PurchaseHeader: Record "Purchase Header";
        PurchaseHeaderBuffer: Record "Purchase Header" temporary;
        TemplateField: Record "CDC Template Field";
        DocumentValue: Record "CDC Document value";
        PurchasesPayablesSetup: Record "Purchases & Payables Setup";
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
        CaptureMgt: Codeunit "CDC Capture Management";
        FilterString: Text;
        FoundPurchaseOrders: Text;
        Pos: Integer;
    begin
        DocumentWord.SETRANGE("Document No.", DCDocument."No.");

        // Create appropriate Filter string from Purchase Setup >>>
        PurchasesPayablesSetup.GET;
        NoSeries.GET(PurchasesPayablesSetup."Order Nos.");
        NoSeriesLine.SETRANGE("Series Code", NoSeries.Code);
        NoSeriesLine.SETFILTER("Starting Date", '%1|<=%2', 0D, TODAY);
        NoSeriesLine.SETRANGE(Open, TRUE);
        IF NoSeriesLine.FINDLAST THEN BEGIN
            Pos := 1;

            WHILE (Pos <= STRLEN(NoSeriesLine."Starting No.")) DO BEGIN
                IF NoSeriesLine."Starting No."[Pos] IN ['0' .. '9'] THEN
                    FilterString += '?'
                ELSE
                    FilterString += FORMAT(NoSeriesLine."Starting No."[Pos]);
                Pos += 1;
            END;
        END;

        IF STRLEN(FilterString) = 0 THEN
            EXIT;
        // Iterate through Document Word table and filter for our PO number filter string
        DocumentWord.SETFILTER(Word, FilterString);
        IF DocumentWord.FINDSET THEN
            REPEAT
                // Check if there is a PO in the system with the matched word
                IF PurchaseHeader.GET(PurchaseHeader."Document Type"::Order, COPYSTR(UPPERCASE(DocumentWord.Word), 1, MAXSTRLEN(PurchaseHeader."No."))) THEN BEGIN
                    // Check if the number exists in the temp. PO buffer
                    IF NOT PurchaseHeaderBuffer.GET(PurchaseHeader."Document Type", PurchaseHeader."No.") THEN BEGIN
                        PurchaseHeaderBuffer := PurchaseHeader;
                        PurchaseHeaderBuffer.INSERT;
                    END;
                END;
            UNTIL DocumentWord.NEXT = 0;

        // Iterate through all found PO's and create the string, that can be used for order matching
        IF PurchaseHeaderBuffer.FINDFIRST THEN
            REPEAT
                IF (STRLEN(FoundPurchaseOrders) + STRLEN(PurchaseHeaderBuffer."No.") + 1) <= MAXSTRLEN(DocumentValue."Value (Text)") THEN BEGIN
                    IF (STRLEN(FoundPurchaseOrders) > 0) THEN
                        FoundPurchaseOrders += ',';
                    FoundPurchaseOrders += PurchaseHeaderBuffer."No.";
                END;
            UNTIL PurchaseHeaderBuffer.NEXT = 0;

        TemplateField.GET(DCDocument."Template No.", TemplateField.Type::Header, 'OURDOCNO');
        CaptureMgt.UpdateFieldValue(DCDocument."No.", 0, 0, TemplateField, FoundPurchaseOrders, FALSE, FALSE);
    end;
}

