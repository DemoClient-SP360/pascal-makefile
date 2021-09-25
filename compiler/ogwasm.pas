{
    Copyright (c) 2021 by Nikolay Nikolov

    Contains the WebAssembly binary module format reader and writer

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

 ****************************************************************************
}
unit ogwasm;

{$i fpcdefs.inc}

interface

    uses
      { common }
      cclasses,globtype,
      { target }
      systems,cpubase,
      { assembler }
      aasmbase,assemble,aasmcpu,
      { WebAssembly module format definitions }
      wasmbase,
      { output }
      ogbase,
      owbase;

    type

      { TWasmObjRelocation }

      TWasmObjRelocation = class(TObjRelocation)
      end;

      { TWasmObjSymbolExtraData }

      TWasmObjSymbolExtraData = class(TFPHashObject)
        TypeIdx: Integer;
        ImportModule: string;
        ImportName: string;
        Locals: array of TWasmBasicType;
        constructor Create(HashObjectList: TFPHashObjectList; const s: TSymStr);
        procedure AddLocal(bastyp: TWasmBasicType);
      end;

      { TWasmObjSection }

      TWasmObjSection = class(TObjSection)
      public
        SegIdx: Integer;
        SegOfs: qword;
        function IsCode: Boolean;
        function IsData: Boolean;
      end;

      { TWasmObjData }

      TWasmObjData = class(TObjData)
      private
        FFuncTypes: array of TWasmFuncType;
        FObjSymbolsExtraDataList: TFPHashObjectList;
        FLastFuncName: string;

        function is_smart_section(atype:TAsmSectiontype):boolean;
        function sectionname_gas(atype:TAsmSectiontype;const aname:string;aorder:TAsmSectionOrder):string;
      public
        constructor create(const n:string);override;
        destructor destroy; override;
        function sectionname(atype:TAsmSectiontype;const aname:string;aorder:TAsmSectionOrder):string;override;
        procedure writeReloc(Data:TRelocDataInt;len:aword;p:TObjSymbol;Reloctype:TObjRelocationType);override;
        function AddOrCreateObjSymbolExtraData(const symname:TSymStr): TWasmObjSymbolExtraData;
        function AddFuncType(wft: TWasmFuncType): integer;
        procedure DeclareFuncType(ft: tai_functype);
        procedure DeclareImportModule(aim: tai_import_module);
        procedure DeclareImportName(ain: tai_import_name);
        procedure DeclareLocal(al: tai_local);
      end;

      { TWasmObjOutput }

      TWasmObjOutput = class(tObjOutput)
      private
        FData: TWasmObjData;
        FWasmSections: array [TWasmSectionID] of tdynamicarray;
        procedure WriteUleb(d: tdynamicarray; v: uint64);
        procedure WriteUleb(w: TObjectWriter; v: uint64);
        procedure WriteSleb(d: tdynamicarray; v: int64);
        procedure WriteByte(d: tdynamicarray; b: byte);
        procedure WriteName(d: tdynamicarray; const s: string);
        procedure WriteWasmSection(wsid: TWasmSectionID);
        procedure CopyDynamicArray(src, dest: tdynamicarray; size: QWord);
        procedure WriteZeros(dest: tdynamicarray; size: QWord);
        procedure WriteWasmResultType(dest: tdynamicarray; wrt: TWasmResultType);
        procedure WriteWasmBasicType(dest: tdynamicarray; wbt: TWasmBasicType);
        function IsExternalFunction(sym: TObjSymbol): Boolean;
        procedure WriteFunctionLocals(dest: tdynamicarray; ed: TWasmObjSymbolExtraData);
        procedure WriteFunctionCode(dest: tdynamicarray; objsym: TObjSymbol);
      protected
        function writeData(Data:TObjData):boolean;override;
      public
        constructor create(AWriter:TObjectWriter);override;
        destructor destroy;override;
      end;

      { TWasmAssembler }

      TWasmAssembler = class(tinternalassembler)
        constructor create(info: pasminfo; smart:boolean);override;
      end;

implementation

    uses
      verbose;

{****************************************************************************
                              TWasmObjSymbolExtraData
****************************************************************************}

    constructor TWasmObjSymbolExtraData.Create(HashObjectList: TFPHashObjectList; const s: TSymStr);
      begin
        inherited Create(HashObjectList,s);
        TypeIdx:=-1;
      end;

    procedure TWasmObjSymbolExtraData.AddLocal(bastyp: TWasmBasicType);
      begin
        SetLength(Locals,Length(Locals)+1);
        Locals[High(Locals)]:=bastyp;
      end;

{****************************************************************************
                              TWasmObjSection
****************************************************************************}

    function TWasmObjSection.IsCode: Boolean;
      const
        CodePrefix = '.text';
      begin
        result:=(Length(Name)>=Length(CodePrefix)) and
          (Copy(Name,1,Length(CodePrefix))=CodePrefix);
      end;

    function TWasmObjSection.IsData: Boolean;
      begin
        result:=not IsCode;
      end;

{****************************************************************************
                                TWasmObjData
****************************************************************************}

    function TWasmObjData.is_smart_section(atype: TAsmSectiontype): boolean;
      begin
        { For bss we need to set some flags that are target dependent,
          it is easier to disable it for smartlinking. It doesn't take up
          filespace }
        result:=not(target_info.system in systems_darwin) and
           create_smartlink_sections and
           (atype<>sec_toc) and
           (atype<>sec_user) and
           { on embedded systems every byte counts, so smartlink bss too }
           ((atype<>sec_bss) or (target_info.system in (systems_embedded+systems_freertos)));
      end;

    function TWasmObjData.sectionname_gas(atype: TAsmSectiontype;
        const aname: string; aorder: TAsmSectionOrder): string;
      const
        secnames : array[TAsmSectiontype] of string[length('__DATA, __datacoal_nt,coalesced')] = ('','',
          '.text',
          '.data',
{ why doesn't .rodata work? (FK) }
{ sometimes we have to create a data.rel.ro instead of .rodata, e.g. for  }
{ vtables (and anything else containing relocations), otherwise those are }
{ not relocated properly on e.g. linux/ppc64. g++ generates there for a   }
{ vtable for a class called Window:                                       }
{ .section .data.rel.ro._ZTV6Window,"awG",@progbits,_ZTV6Window,comdat    }
{ TODO: .data.ro not yet working}
{$if defined(arm) or defined(riscv64) or defined(powerpc)}
          '.rodata',
{$else defined(arm) or defined(riscv64) or defined(powerpc)}
          '.data',
{$endif defined(arm) or defined(riscv64) or defined(powerpc)}
          '.rodata',
          '.bss',
          '.threadvar',
          '.pdata',
          '', { stubs }
          '__DATA,__nl_symbol_ptr',
          '__DATA,__la_symbol_ptr',
          '__DATA,__mod_init_func',
          '__DATA,__mod_term_func',
          '.stab',
          '.stabstr',
          '.idata$2','.idata$4','.idata$5','.idata$6','.idata$7','.edata',
          '.eh_frame',
          '.debug_frame','.debug_info','.debug_line','.debug_abbrev','.debug_aranges','.debug_ranges',
          '.fpc',
          '.toc',
          '.init',
          '.fini',
          '.objc_class',
          '.objc_meta_class',
          '.objc_cat_cls_meth',
          '.objc_cat_inst_meth',
          '.objc_protocol',
          '.objc_string_object',
          '.objc_cls_meth',
          '.objc_inst_meth',
          '.objc_cls_refs',
          '.objc_message_refs',
          '.objc_symbols',
          '.objc_category',
          '.objc_class_vars',
          '.objc_instance_vars',
          '.objc_module_info',
          '.objc_class_names',
          '.objc_meth_var_types',
          '.objc_meth_var_names',
          '.objc_selector_strs',
          '.objc_protocol_ext',
          '.objc_class_ext',
          '.objc_property',
          '.objc_image_info',
          '.objc_cstring_object',
          '.objc_sel_fixup',
          '__DATA,__objc_data',
          '__DATA,__objc_const',
          '.objc_superrefs',
          '__DATA, __datacoal_nt,coalesced',
          '.objc_classlist',
          '.objc_nlclasslist',
          '.objc_catlist',
          '.obcj_nlcatlist',
          '.objc_protolist',
          '.stack',
          '.heap',
          '.gcc_except_table',
          '.ARM.attributes'
        );
      var
        sep     : string[3];
        secname : string;
      begin
        secname:=secnames[atype];

        if (atype=sec_fpc) and (Copy(aname,1,3)='res') then
          begin
            result:=secname+'.'+aname;
            exit;
          end;

        if atype=sec_threadvar then
          begin
            if (target_info.system in (systems_windows+systems_wince)) then
              secname:='.tls'
            else if (target_info.system in systems_linux) then
              secname:='.tbss';
          end;

        { go32v2 stub only loads .text and .data sections, and allocates space for .bss.
          Thus, data which normally goes into .rodata and .rodata_norel sections must
          end up in .data section }
        if (atype in [sec_rodata,sec_rodata_norel]) and
          (target_info.system in [system_i386_go32v2,system_m68k_palmos]) then
          secname:='.data';

        { Windows correctly handles reallocations in readonly sections }
        if (atype=sec_rodata) and
          (target_info.system in systems_all_windows+systems_nativent-[system_i8086_win16]) then
          secname:='.rodata';

        { section type user gives the user full controll on the section name }
        if atype=sec_user then
          secname:=aname;

        if is_smart_section(atype) and (aname<>'') then
          begin
            case aorder of
              secorder_begin :
                sep:='.b_';
              secorder_end :
                sep:='.z_';
              else
                sep:='.n_';
            end;
            result:=secname+sep+aname
          end
        else
          result:=secname;
      end;

    constructor TWasmObjData.create(const n: string);
      begin
        inherited;
        CObjSection:=TWasmObjSection;
        FObjSymbolsExtraDataList:=TFPHashObjectList.Create;
      end;

    destructor TWasmObjData.destroy;
      var
        i: Integer;
      begin
        FObjSymbolsExtraDataList.Free;
        for i:=low(FFuncTypes) to high(FFuncTypes) do
          begin
            FFuncTypes[i].free;
            FFuncTypes[i]:=nil;
          end;
        inherited destroy;
      end;

    function TWasmObjData.sectionname(atype: TAsmSectiontype;
        const aname: string; aorder: TAsmSectionOrder): string;
      begin
        if (atype=sec_fpc) or (atype=sec_threadvar) then
          atype:=sec_data;
        Result:=sectionname_gas(atype, aname, aorder);
      end;

    procedure TWasmObjData.writeReloc(Data: TRelocDataInt; len: aword;
        p: TObjSymbol; Reloctype: TObjRelocationType);
      const
        leb_zero: array[0..4] of byte=($80,$80,$80,$80,$00);
      var
        objreloc: TWasmObjRelocation;
      begin
        if CurrObjSec=nil then
          internalerror(200403072);
        objreloc:=nil;
        case Reloctype of
          RELOC_FUNCTION_INDEX_LEB:
            begin
              if Data<>0 then
                internalerror(2021092502);
              if len<>5 then
                internalerror(2021092503);
              if not assigned(p) then
                internalerror(2021092504);
              if p.bind<>AB_EXTERNAL then
                internalerror(2021092505);
              objreloc:=TWasmObjRelocation.CreateSymbol(CurrObjSec.Size,p,Reloctype);
              CurrObjSec.ObjRelocations.Add(objreloc);
              writebytes(leb_zero,5);
            end;
          RELOC_ABSOLUTE:
            begin
              { todo... }
            end;
          else
            internalerror(2021092501);
        end;
      end;

    function TWasmObjData.AddOrCreateObjSymbolExtraData(const symname: TSymStr): TWasmObjSymbolExtraData;
      begin
        result:=TWasmObjSymbolExtraData(FObjSymbolsExtraDataList.Find(symname));
        if not assigned(result) then
          result:=TWasmObjSymbolExtraData.Create(FObjSymbolsExtraDataList,symname);
      end;

    function TWasmObjData.AddFuncType(wft: TWasmFuncType): integer;
      var
        i: Integer;
      begin
        for i:=low(FFuncTypes) to high(FFuncTypes) do
          if wft.Equals(FFuncTypes[i]) then
            exit(i);

        result:=Length(FFuncTypes);
        SetLength(FFuncTypes,result+1);
        FFuncTypes[result]:=TWasmFuncType.Create(wft);
      end;

    procedure TWasmObjData.DeclareFuncType(ft: tai_functype);
      var
        i: Integer;
        ObjSymExtraData: TWasmObjSymbolExtraData;
      begin
        FLastFuncName:=ft.funcname;
        i:=AddFuncType(ft.functype);
        ObjSymExtraData:=AddOrCreateObjSymbolExtraData(ft.funcname);
        ObjSymExtraData.TypeIdx:=i;
      end;

    procedure TWasmObjData.DeclareImportModule(aim: tai_import_module);
      var
        ObjSymExtraData: TWasmObjSymbolExtraData;
      begin
        ObjSymExtraData:=AddOrCreateObjSymbolExtraData(aim.symname);
        ObjSymExtraData.ImportModule:=aim.importmodule;
      end;

    procedure TWasmObjData.DeclareImportName(ain: tai_import_name);
      var
        ObjSymExtraData: TWasmObjSymbolExtraData;
      begin
        ObjSymExtraData:=AddOrCreateObjSymbolExtraData(ain.symname);
        ObjSymExtraData.ImportName:=ain.importname;
      end;

    procedure TWasmObjData.DeclareLocal(al: tai_local);
      var
        ObjSymExtraData: TWasmObjSymbolExtraData;
      begin
        ObjSymExtraData:=TWasmObjSymbolExtraData(FObjSymbolsExtraDataList.Find(FLastFuncName));
        ObjSymExtraData.AddLocal(al.bastyp);
      end;

{****************************************************************************
                               TWasmObjOutput
****************************************************************************}

    procedure TWasmObjOutput.WriteUleb(d: tdynamicarray; v: uint64);
      var
        b: byte;
      begin
        repeat
          b:=byte(v) and 127;
          v:=v shr 7;
          if v<>0 then
            b:=b or 128;
          d.write(b,1);
        until v=0;
      end;

    procedure TWasmObjOutput.WriteUleb(w: TObjectWriter; v: uint64);
      var
        b: byte;
      begin
        repeat
          b:=byte(v) and 127;
          v:=v shr 7;
          if v<>0 then
            b:=b or 128;
          w.write(b,1);
        until v=0;
      end;

    procedure TWasmObjOutput.WriteSleb(d: tdynamicarray; v: int64);
      var
        b: byte;
        Done: Boolean=false;
      begin
        repeat
          b:=byte(v) and 127;
          v:=SarInt64(v,7);
          if ((v=0) and ((b and 64)=0)) or ((v=-1) and ((b and 64)<>0)) then
            Done:=true
          else
            b:=b or 128;
          d.write(b,1);
        until Done;
      end;

    procedure TWasmObjOutput.WriteByte(d: tdynamicarray; b: byte);
      begin
        d.write(b,1);
      end;

    procedure TWasmObjOutput.WriteName(d: tdynamicarray; const s: string);
      begin
        WriteUleb(d,Length(s));
        d.writestr(s);
      end;

    procedure TWasmObjOutput.WriteWasmSection(wsid: TWasmSectionID);
      var
        b: byte;
      begin
        b:=ord(wsid);
        Writer.write(b,1);
        WriteUleb(Writer,FWasmSections[wsid].size);
        Writer.writearray(FWasmSections[wsid]);
      end;

    procedure TWasmObjOutput.CopyDynamicArray(src, dest: tdynamicarray; size: QWord);
      var
        buf: array [0..4095] of byte;
        bs: Integer;
      begin
        while size>0 do
          begin
            if size<SizeOf(buf) then
              bs:=Integer(size)
            else
              bs:=SizeOf(buf);
            src.read(buf,bs);
            dest.write(buf,bs);
            dec(size,bs);
          end;
      end;

    procedure TWasmObjOutput.WriteZeros(dest: tdynamicarray; size: QWord);
      var
        buf : array[0..1023] of byte;
        bs: Integer;
      begin
        fillchar(buf,sizeof(buf),0);
        while size>0 do
          begin
            if size<SizeOf(buf) then
              bs:=Integer(size)
            else
              bs:=SizeOf(buf);
            dest.write(buf,bs);
            dec(size,bs);
          end;
      end;

    procedure TWasmObjOutput.WriteWasmResultType(dest: tdynamicarray; wrt: TWasmResultType);
      var
        i: Integer;
      begin
        WriteUleb(dest,Length(wrt));
        for i:=low(wrt) to high(wrt) do
          WriteWasmBasicType(dest,wrt[i]);
      end;

    procedure TWasmObjOutput.WriteWasmBasicType(dest: tdynamicarray; wbt: TWasmBasicType);
      begin
        case wbt of
          wbt_i32:
            WriteByte(dest,$7F);
          wbt_i64:
            WriteByte(dest,$7E);
          wbt_f32:
            WriteByte(dest,$7D);
          wbt_f64:
            WriteByte(dest,$7C);
        end;
      end;

    function TWasmObjOutput.IsExternalFunction(sym: TObjSymbol): Boolean;
      begin
        result:=(sym.bind=AB_EXTERNAL) and (TWasmObjData(sym.ObjData).FObjSymbolsExtraDataList.Find(sym.Name)<>nil);
      end;

    procedure TWasmObjOutput.WriteFunctionLocals(dest: tdynamicarray; ed: TWasmObjSymbolExtraData);
      var
        i,
        rle_entries,
        cnt: Integer;
        lasttype: TWasmBasicType;
      begin
        if Length(ed.Locals)=0 then
          begin
            WriteUleb(dest,0);
            exit;
          end;

        rle_entries:=1;
        for i:=low(ed.Locals)+1 to high(ed.Locals) do
          if ed.Locals[i]<>ed.Locals[i-1] then
            inc(rle_entries);

        WriteUleb(dest,rle_entries);
        lasttype:=ed.Locals[Low(ed.Locals)];
        cnt:=1;
        for i:=low(ed.Locals)+1 to high(ed.Locals) do
          if ed.Locals[i]=ed.Locals[i-1] then
            inc(cnt)
          else
            begin
              WriteUleb(dest,cnt);
              WriteWasmBasicType(dest,lasttype);
              lasttype:=ed.Locals[i];
              cnt:=1;
            end;
        WriteUleb(dest,cnt);
        WriteWasmBasicType(dest,lasttype);
      end;

    procedure TWasmObjOutput.WriteFunctionCode(dest: tdynamicarray; objsym: TObjSymbol);
      var
        encoded_locals: tdynamicarray;
        ObjSymExtraData: TWasmObjSymbolExtraData;
        codelen: LongWord;
        ObjSection: TObjSection;
        codeexprlen: QWord;
      begin
        ObjSymExtraData:=TWasmObjSymbolExtraData(FData.FObjSymbolsExtraDataList.Find(objsym.Name));
        ObjSection:=objsym.objsection;
        ObjSection.Data.seek(objsym.address);
        codeexprlen:=ObjSection.Size-objsym.address;

        encoded_locals:=tdynamicarray.Create(64);
        WriteFunctionLocals(encoded_locals,ObjSymExtraData);
        codelen:=encoded_locals.size+codeexprlen+1;
        WriteUleb(dest,codelen);
        encoded_locals.seek(0);
        CopyDynamicArray(encoded_locals,dest,encoded_locals.size);
        CopyDynamicArray(ObjSection.Data,dest,codeexprlen);
        WriteByte(dest,$0B);
        encoded_locals.Free;
      end;

    function TWasmObjOutput.writeData(Data:TObjData):boolean;
      var
        i: Integer;
        objsec: TWasmObjSection;
        segment_count: Integer = 0;
        cur_seg_ofs: qword = 0;
        types_count,
        imports_count: Integer;
        import_functions_count: Integer = 0;
        functions_count: Integer = 0;
        objsym: TObjSymbol;
      begin
        FData:=TWasmObjData(Data);
        for i:=0 to Data.ObjSymbolList.Count-1 do
          begin
            objsym:=TObjSymbol(Data.ObjSymbolList[i]);
            if IsExternalFunction(objsym) then
              Inc(import_functions_count);
            if objsym.typ=AT_FUNCTION then
              Inc(functions_count);
          end;

        types_count:=Length(FData.FFuncTypes);
        WriteUleb(FWasmSections[wsiType],types_count);
        for i:=0 to types_count-1 do
          with FData.FFuncTypes[i] do
            begin
              WriteByte(FWasmSections[wsiType],$60);
              WriteWasmResultType(FWasmSections[wsiType],params);
              WriteWasmResultType(FWasmSections[wsiType],results);
            end;

        for i:=0 to Data.ObjSectionList.Count-1 do
          begin
            objsec:=TWasmObjSection(Data.ObjSectionList[i]);
            if objsec.IsCode then
              objsec.SegIdx:=-1
            else
              begin
                objsec.SegIdx:=segment_count;
                objsec.SegOfs:=cur_seg_ofs;
                Inc(segment_count);
                Inc(cur_seg_ofs,objsec.Size);
              end;
          end;

        WriteUleb(FWasmSections[wsiData],segment_count);
        for i:=0 to Data.ObjSectionList.Count-1 do
          begin
            objsec:=TWasmObjSection(Data.ObjSectionList[i]);
            if objsec.IsData then
              begin
                WriteByte(FWasmSections[wsiData],0);
                WriteByte(FWasmSections[wsiData],$41);
                WriteSleb(FWasmSections[wsiData],objsec.SegOfs);
                WriteByte(FWasmSections[wsiData],$0b);
                WriteUleb(FWasmSections[wsiData],objsec.Size);
                if oso_Data in objsec.SecOptions then
                  begin
                    objsec.Data.seek(0);
                    CopyDynamicArray(objsec.Data,FWasmSections[wsiData],objsec.Size);
                  end
                else
                  begin
                    WriteZeros(FWasmSections[wsiData],objsec.Size);
                  end;
              end;
          end;

        WriteUleb(FWasmSections[wsiDataCount],segment_count);

        imports_count:=3+import_functions_count;
        WriteUleb(FWasmSections[wsiImport],imports_count);
        { import[0] }
        WriteName(FWasmSections[wsiImport],'env');
        WriteName(FWasmSections[wsiImport],'__linear_memory');
        WriteByte(FWasmSections[wsiImport],$02);  { mem }
        WriteByte(FWasmSections[wsiImport],$00);  { min }
        WriteUleb(FWasmSections[wsiImport],1);    { 1 page }
        { import[1] }
        WriteName(FWasmSections[wsiImport],'env');
        WriteName(FWasmSections[wsiImport],'__stack_pointer');
        WriteByte(FWasmSections[wsiImport],$03);  { global }
        WriteByte(FWasmSections[wsiImport],$7F);  { i32 }
        WriteByte(FWasmSections[wsiImport],$01);  { var }
        { import[2]..import[imports_count-2] }
        for i:=0 to Data.ObjSymbolList.Count-1 do
          begin
            objsym:=TObjSymbol(Data.ObjSymbolList[i]);
            if IsExternalFunction(objsym) then
              begin
                WriteName(FWasmSections[wsiImport],'env');
                WriteName(FWasmSections[wsiImport],objsym.Name);
                WriteByte(FWasmSections[wsiImport],$00);  { func }
                WriteUleb(FWasmSections[wsiImport],TWasmObjSymbolExtraData(FData.FObjSymbolsExtraDataList.Find(objsym.Name)).TypeIdx);
              end;
          end;
        { import[imports_count-1] }
        WriteName(FWasmSections[wsiImport],'env');
        WriteName(FWasmSections[wsiImport],'__indirect_function_table');
        WriteByte(FWasmSections[wsiImport],$01);  { table }
        WriteByte(FWasmSections[wsiImport],$70);  { funcref }
        WriteByte(FWasmSections[wsiImport],$00);  { min }
        WriteUleb(FWasmSections[wsiImport],1);    { 1 }

        WriteUleb(FWasmSections[wsiFunction],functions_count);
        WriteUleb(FWasmSections[wsiCode],functions_count);
        for i:=0 to Data.ObjSymbolList.Count-1 do
          begin
            objsym:=TObjSymbol(Data.ObjSymbolList[i]);
            if objsym.typ=AT_FUNCTION then
              begin
                WriteUleb(FWasmSections[wsiFunction],TWasmObjSymbolExtraData(FData.FObjSymbolsExtraDataList.Find(objsym.Name)).TypeIdx);
                WriteFunctionCode(FWasmSections[wsiCode],objsym);
              end;
          end;

        Writer.write(WasmModuleMagic,SizeOf(WasmModuleMagic));
        Writer.write(WasmVersion,SizeOf(WasmVersion));

        WriteWasmSection(wsiType);
        WriteWasmSection(wsiImport);
        WriteWasmSection(wsiFunction);
        WriteWasmSection(wsiDataCount);
        WriteWasmSection(wsiCode);
        WriteWasmSection(wsiData);

        Writeln('ObjSymbolList:');
        for i:=0 to Data.ObjSymbolList.Count-1 do
          begin
            objsym:=TObjSymbol(Data.ObjSymbolList[i]);
            Write(objsym.Name, ' bind=', objsym.Bind, ' typ=', objsym.typ, ' address=', objsym.address, ' objsection=');
            if assigned(objsym.objsection) then
              Write(objsym.objsection.Name)
            else
              Write('nil');
            Writeln;
          end;

        Writeln('ObjSectionList:');
        for i:=0 to Data.ObjSectionList.Count-1 do
          begin
            objsec:=TWasmObjSection(Data.ObjSectionList[i]);
            Writeln(objsec.Name, ' IsCode=', objsec.IsCode, ' IsData=', objsec.IsData, ' Size=', objsec.Size, ' MemPos=', objsec.MemPos, ' DataPos=', objsec.DataPos, ' SegIdx=', objsec.SegIdx);
          end;

        result:=true;
      end;

    constructor TWasmObjOutput.create(AWriter: TObjectWriter);
      var
        i: TWasmSectionID;
      begin
        inherited;
        cobjdata:=TWasmObjData;
        for i in TWasmSectionID do
          FWasmSections[i] := tdynamicarray.create(SectionDataMaxGrow);
      end;

    destructor TWasmObjOutput.destroy;
      var
        i: TWasmSectionID;
      begin
        for i in TWasmSectionID do
          FWasmSections[i].Free;
        inherited destroy;
      end;

{****************************************************************************
                               TWasmAssembler
****************************************************************************}

    constructor TWasmAssembler.Create(info: pasminfo; smart:boolean);
      begin
        inherited;
        CObjOutput:=TWasmObjOutput;
      end;

{*****************************************************************************
                                  Initialize
*****************************************************************************}
{$ifdef wasm32}
    const
       as_wasm32_wasm_info : tasminfo =
          (
            id     : as_wasm32_wasm;
            idtxt  : 'OMF';
            asmbin : '';
            asmcmd : '';
            supported_targets : [system_wasm32_embedded,system_wasm32_wasi];
            flags : [af_outputbinary,af_smartlink_sections];
            labelprefix : '..@';
            labelmaxlen : -1;
            comment : '; ';
            dollarsign: '$';
          );
{$endif wasm32}

initialization
{$ifdef wasm32}
  RegisterAssembler(as_wasm32_wasm_info,TWasmAssembler);
{$endif wasm32}
end.