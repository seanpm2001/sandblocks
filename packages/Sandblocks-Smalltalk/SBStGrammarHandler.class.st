Class {
	#name : #SBStGrammarHandler,
	#superclass : #SBGrammarHandler,
	#category : #'Sandblocks-Smalltalk'
}

{ #category : #'as yet unclassified' }
SBStGrammarHandler class >> messageSendClass [

	^ SBStMessageSend
]

{ #category : #actions }
SBStGrammarHandler >> browseImplementors [
	<action>

	| list |
	self block selector ifNotNil: [:sel |
		list := self systemNavigation allImplementorsOf: sel asSymbol.
		
		(self block sandblockEditor isSingleArtefactView or: [list size > 1]) ifTrue: [
			self block sandblockEditor model ifNotNil: [:model | (model isKindOf: MessageTrace) ifTrue: [^ model browseAllImplementorsOf: sel asSymbol requestor: #modelMenu]].
			^ self changeToBlockView: (self systemNavigation browseAllImplementorsOf: sel asSymbol)].
		
		self block sandblockEditor open: list first compiledMethod]
]

{ #category : #actions }
SBStGrammarHandler >> browseSenders [
	<action>

	self block selector ifNotNil: [:sel | | calls |
		calls := self systemNavigation allCallsOn: sel asSymbol.
		calls ifEmpty: [^ self].
		
		(self block sandblockEditor isSingleArtefactView or: [calls size > 1]) ifTrue: [
			self block sandblockEditor model ifNotNil: [:model | (model isKindOf: MessageTrace) ifTrue: [^ model browseAllCallsOn: sel asSymbol requestor: #modelMenu]].
			^ self changeToBlockView: (self systemNavigation browseAllCallsOn: sel asSymbol)].
		
		self block sandblockEditor open: calls first compiledMethod]
]

{ #category : #'action helpers' }
SBStGrammarHandler >> buildEachCommandForSelected: aBlock callingAlternativesBuilder: aSelector [

	| parent variant before |
	parent := aBlock parentSandblock.
	before := aBlock  submorphBefore.
	variant := SBVariant new.
	^ SBWrapCommand new
		outer: variant;
		inner: aBlock;
		wrap:  [:outer :inner |
			variant 
				named: (self variantNameFor: {inner} in: parent preceedingBlock: before)
				alternatives: (self perform: aSelector with: {inner})
				activeIndex: 2];
		yourself
]

{ #category : #'action helpers' }
SBStGrammarHandler >> buildMultiselectCommandOnVariant: aVariant selected: aCollectionOfBlocks callingAlternativesBuilder: aSelector [

	| parent before |
	parent := aCollectionOfBlocks first parentSandblock. 
	before := aCollectionOfBlocks first submorphBefore.
	^ SBWrapConsecutiveCommand new
		selectAfter: #block;
		outer: aVariant;
		targets: aCollectionOfBlocks;
		wrap:  [:outer :inner |
			aVariant 
				named: (self variantNameFor: inner in: parent preceedingBlock: before)
				alternatives: (self perform: aSelector with: inner)
				activeIndex: 2];
		yourself
]

{ #category : #'callback helpers' }
SBStGrammarHandler >> changeToBlockView: aWindow [

	aWindow isSystemWindow ifFalse: [^ self].
	
	aWindow model contentsSymbol ~= #blockEditor
		ifTrue: [aWindow model toggleBlockEditor].
	^ aWindow
]

{ #category : #testing }
SBStGrammarHandler >> characterCanStartInput: aCharacter [

	^ aCharacter isAlphaNumeric or: [aCharacter isSpecial]
]

{ #category : #actions }
SBStGrammarHandler >> createNewEmptyModule [
	<action>

	
	self block sandblockEditor createEmptySmalltalkMethod
]

{ #category : #actions }
SBStGrammarHandler >> debugExpression [
	<action>
	<actionValidIf: #isExpression>

	| artefact context |
	artefact := SBExecutionEnvironment value ifNil: [self block containingArtefact].
	
	context := artefact ifNotNil: #evaluationContext.
	(Process
		forMethod: (Compiler new
			compileNoPattern: self block sourceString
			in: (artefact ifNotNil: #relatedClass ifNil: [nil class])
			context: (context ifNotNil: #receiver)
			notifying: artefact
			ifFail: nil) generateWithTempNames
		receiver: (context ifNil: [artefact ifNotNil: #evaluationReceiver] ifNotNil: #receiver)) debugWithTitle: 'Debug it'
]

{ #category : #'action helpers' }
SBStGrammarHandler >> defaultAlternativesForBlocks: aCollectionOfBlocks [

	^ {
		SBNamedBlock block: (SBStBlockBody new statements: aCollectionOfBlocks).
		SBNamedBlock block: (SBStBlockBody new statements: aCollectionOfBlocks veryDeepCopy). } 
]

{ #category : #'action helpers' }
SBStGrammarHandler >> defaultOptionalAlternativesForBlocks: aCollectionOfBlocks [

	^ {
		SBNamedBlock block: (SBStBlockBody new statements: aCollectionOfBlocks) named:'with'. 
		SBNamedBlock block: (SBStBlockBody empty) named:'without'.} 
]

{ #category : #actions }
SBStGrammarHandler >> doExpression [
	<action>
	
	| result |
	result := super doExpression.
	self block containingArtefact ifNotNil: [
		self block containingArtefact cacheType: result class for: self]
]

{ #category : #'callback helpers' }
SBStGrammarHandler >> emptyLine: aBlock [
	<action>
	<actionValidIf: #isStatement>

	aBlock sandblockEditor do: (SBReplaceCommand new
		target: aBlock;
		replacer: self newNullBlock)
]

{ #category : #actions }
SBStGrammarHandler >> evaluateExpression [
	<action>
	<actionValidIf: #canEvaluate>

	| result |
	result := super evaluateExpression.
	self block containingArtefact ifNotNil: [self block containingArtefact cacheType: result class for: self].
	^ result
]

{ #category : #actions }
SBStGrammarHandler >> extractMethod [
	<multiSelectAction>

	self block sandblockEditor multiSelectionIsConsecutive ifFalse: [^ self].
	
	self block sandblockEditor doMultiSelection: [:extracting | | arguments localBindings method |
		self flag: #todo.
		" consider write vs read access "
		localBindings := extracting gather: #resolveLocalBindings.
		localBindings := ((KeyedSet keyBlock: #name)
			addAll: localBindings;
			yourself) asArray.
		arguments := localBindings collect: [:arg | SBStName contents: arg contents].
		
		method := SBStMethod new
			selector: (localBindings size = 0
					ifTrue: [(UIManager default request: 'Name of Method?') ifEmpty: [^ self]]
					ifFalse: [#extracted numArgs: localBindings size])
				arguments: localBindings veryDeepCopy
				class: self block containingArtefact methodClass;
			body: SBStBlockBody new.
		
		SBCombinedCommand newWith: {
			SBReplaceConsecutiveCommand new
				targets: extracting;
				replacer: (SBStMessageSend new
					receiver: (SBStName contents: 'self')
					selector: method selector
					arguments: arguments veryDeepCopy)}, (extracting withIndexCollect: [:stmt :index |
			SBInsertCommand new
				container: method body;
				index: index + 1;
				morph: stmt;
				yourself]), {
			SBWrapCommand new
				inner: extracting last;
				outer: SBStReturn new;
				wrap: [:outer :inner | outer expression: inner].
			SBEditorOpenMorphCommand new
				editor: self block sandblockEditor;
				morph: method;
				isUnsaved: true;
				yourself}]
]

{ #category : #actions }
SBStGrammarHandler >> extractVariable [
	<action>

	| name var block |
	name := (UIManager default request: 'Name for variable?') ifEmpty: [^ self].
	var := SBStName contents: name.
	block := self block containingBlock.
	
	self block sandblockEditor do: (SBCombinedCommand newWith: {
		block declareTemporaryVariableCommand: name.
		SBReplaceCommand new
			target: self block;
			replacer: var.
		SBInsertCommand new
			container: block;
			index: ((block statements findFirst: [:s | s isExpression]) + 1 max: 2);
			morph: self block.
		SBWrapCommand new
			inner: self block;
			outer: SBStMessageSend new;
			wrap: [:outer :inner | outer binding: var veryDeepCopy value: inner]})
]

{ #category : #'action helpers' }
SBStGrammarHandler >> insert: aBlock aboveOrBelow: anAboveBoolean [

	| currentStatement index |
	currentStatement := self block containingStatement.
	index := currentStatement owner submorphIndexOf: currentStatement.
	
	self block sandblockEditor do: (SBInsertCommand new
		index: (anAboveBoolean ifTrue: [index] ifFalse: [index + 1]);
		container: currentStatement owner;
		morph: aBlock;
		shouldMergeWithNext: true;
		yourself).
	
	self block sandblockEditor startInput: aBlock at: 1 replacingContents: false
]

{ #category : #actions }
SBStGrammarHandler >> insertHaltAbove [
	<action>

	self insert: SBHalt new aboveOrBelow: true
]

{ #category : #actions }
SBStGrammarHandler >> insertHaltBelow [
	<action>

	self insert: SBHalt new aboveOrBelow: false
]

{ #category : #actions }
SBStGrammarHandler >> insertLabelAbove [
	<action>

	self insert: self newCommentBlock aboveOrBelow: true
]

{ #category : #actions }
SBStGrammarHandler >> insertLabelBelow [
	<action>

	self insert: self newCommentBlock aboveOrBelow: false
]

{ #category : #'block creation' }
SBStGrammarHandler >> newCommentBlock [

	^ SBLabel new
		grammarHandler: self;
		delimiter: #('"' '"');
		yourself
]

{ #category : #actions }
SBStGrammarHandler >> pasteString [
	<action>

	| doIt block baseIndex |
	doIt := PPParser new
		parse: Clipboard clipboardText
		class: nil class
		noPattern: true
		notifying: nil
		ifFail: [^ nil].
	block := doIt block statements last asSandblock.
	baseIndex := self block containingStatement owner submorphIndexOf: self block containingStatement.
	
	self block sandblockEditor do: (SBCombinedCommand new commands: {
		SBReplaceCommand new
			target: self block;
			replacer: block}, (doIt block statements allButLast withIndexCollect: [:statement :index |
		SBInsertCommand new
			index: baseIndex + index - 1;
			container: self block containingStatement owner;
			morph: statement asSandblock])).
	block postDuplicate
]

{ #category : #callbacks }
SBStGrammarHandler >> perform: char for: aBlock empty: aBoolean [

	aBoolean ifTrue: [
		(char isDigit or: [char = $-]) ifTrue: [^ self replace: aBlock with: (SBStNumber new contents: char asString)].
		(char isAlphaNumeric or: [char = $_]) ifTrue: [^ self replace: aBlock with: (SBStName contents: char asString)].
		char = $$ ifTrue: [^ self replace: aBlock with: (SBStCharacter new contents: '')].
		char = $' ifTrue: [^ self replace: aBlock with: (SBStString new contents: '')].
		char = $# ifTrue: [^ self replace: aBlock with: (SBStSymbol new contents: '')].
		(char = $" and: [aBlock parentSandblock isBlockBody]) ifTrue: [^ self replace: aBlock with: self newCommentBlock].
		((char = Character space or: [char = Character cr]) and: [aBlock isStatement]) ifTrue: [^ self emptyLine: aBlock].
		(char = $: and: [aBlock parentSandblock isBlockBody and: [aBlock parentSandblock isMethodBody not]]) ifTrue: [ | block |
			block := aBlock parentSandblock.
			aBlock parentSandblock statements size > 1 ifTrue: [
				aBlock sandblockEditor do: (SBDeleteCommand new
					target: aBlock;
					shouldMergeWithNext: true)].
			^ block addBlockArgument].
		char = $< ifTrue: [^ self replaceWithPragma: aBlock]].
	
	char isSpecial ifTrue: [
		^ self
			wrap: aBlock
			do: [:outer :inner | outer receiver: inner selector: char asString arguments: {outer newNullBlock label: 'arg'}]
			with: self class messageSendClass new
			focusOuter: [:msg | msg messageParts first]].
	char = $( ifTrue: [^ self replace: aBlock with: (SBStArray new type: #literal contents: #())]
]

{ #category : #'callback helpers' }
SBStGrammarHandler >> replaceWithPragma: aBlock [

	| pragma |
	pragma := SBStPragma new.
	aBlock sandblockEditor do: (SBReplaceCommand new
		target: aBlock;
		replacer: pragma;
		shouldMergeWithNext: true).
	^ pragma sandblockEditor
		startInput: pragma messageParts first
		at: 1
		replacingContents: true
]

{ #category : #callbacks }
SBStGrammarHandler >> startOverrideInput: anEvent in: anEditor [

	anEvent keyCharacter isSpecial ifTrue: [
		^ anEditor selection grammarHandler
			block: anEditor selection;
			wrapInMessageSend: anEvent keyCharacter asString].
	super startOverrideInput: anEvent in: anEditor
]

{ #category : #callbacks }
SBStGrammarHandler >> suggestionsFor: aBlock [

	aBlock parentSandblock isMessageSend ifTrue: [^ (aBlock parentSandblock argumentChoicesFor: aBlock) collect: [:literal | SBStLiteralSuggestionItem new literal: literal]].
	^ #()
]

{ #category : #actions }
SBStGrammarHandler >> titleSection [
	<multiSelectAction>
	<actionValidIf: #isUnknown>

	| variant |
	self assert: self block isSelected.
	variant := SBVariant new.
	self block sandblockEditor multiSelectionIsConsecutive ifFalse: [^ self].
	self block sandblockEditor doMultiSelection: [:selected |
		SBWrapConsecutiveCommand new
			selectAfter: #block;
			outer: variant;
			targets: selected;
			wrap:  [:outer :inner |
				variant 
					named: inner printString 
					alternatives: {SBNamedBlock 
						block: (SBStBlockBody new statements: inner) 
						named: 'current'.}
					activeIndex: 1];
			yourself].
		
		self block sandblockEditor select: variant nameBlock.
]

{ #category : #'action helpers' }
SBStGrammarHandler >> useArgument: aNumber [

	| artefact |
	artefact := self block containingArtefact.
	artefact arguments size >= aNumber ifTrue: [ | content editor |
		content := (artefact arguments at: aNumber) contents.
		editor := self block sandblockEditor.
		(self block sandblockEditor cursor mode = #insert or: [self block isExpression not])
			ifTrue: [
				editor handle: (SBTest keyboardEvent: content first).
				editor selection isName ifTrue: [editor selection contents: content]]
			ifFalse: [
				(SBStName contents: content) convertedFor: self block objectInterface do: [:replace |
					editor do: (SBReplaceCommand new
						replacer: replace;
						target: self block)]].
		editor selection startInputAtEnd]
]

{ #category : #'actions input' }
SBStGrammarHandler >> useFifthArgument [
	<inputAction>
	<action>

	self useArgument: 5
]

{ #category : #'actions input' }
SBStGrammarHandler >> useFirstArgument [
	<inputAction>
	<action>

	self useArgument: 1
]

{ #category : #'actions input' }
SBStGrammarHandler >> useFourthArgument [
	<inputAction>
	<action>

	self useArgument: 4
]

{ #category : #'actions input' }
SBStGrammarHandler >> useSecondArgument [
	<inputAction>
	<action>

	self useArgument: 2
]

{ #category : #'actions input' }
SBStGrammarHandler >> useThirdArgument [
	<inputAction>
	<action>

	self useArgument: 3
]

{ #category : #'action helpers' }
SBStGrammarHandler >> variantNameFor: aCollectionOfBlocks in: aParentBlock [
	
	aParentBlock sandblockEditor = aParentBlock ifTrue: [^ aCollectionOfBlocks printString].
	
	aParentBlock isTopLevel ifTrue: [^ aParentBlock printString].

	aParentBlock isMessageSend ifTrue: [^ aCollectionOfBlocks first submorphBefore printString].
	(aParentBlock isAssignment and: [aParentBlock receiver isVariant not]) ifTrue: [^ aParentBlock receiver sourceString, ' := '].
	
	aCollectionOfBlocks size = 1 ifTrue: [^ aCollectionOfBlocks first sourceString].
	
	^ '{1}' format: {(aCollectionOfBlocks collect: [:aBlock | aBlock sourceString]) 
			fold: [:a :b | a, ', ', Character cr, b ]}
]

{ #category : #'action helpers' }
SBStGrammarHandler >> variantNameFor: aCollectionOfBlocks in: aParentBlock preceedingBlock: aNeighbor [
	
	aParentBlock isMessageSend 
		ifTrue: [^ aNeighbor ifNil: [aParentBlock suggestedAlternationName] ifNotNil: [aNeighbor suggestedAlternationName]]. 
	
	(aParentBlock isAssignment and: [aParentBlock receiver isVariant not]) ifTrue: [^ aParentBlock suggestedAlternationName].
	
	aCollectionOfBlocks size = 1 ifTrue: [^ aCollectionOfBlocks first suggestedAlternationName].
	
	^ '{1}' format: {(aCollectionOfBlocks collect: [:aBlock | aBlock suggestedAlternationName]) 
			fold: [:a :b | a, ', ', Character cr, b ]}
]

{ #category : #actions }
SBStGrammarHandler >> wrapAsArgument [
	<action>
	<actionValidIf: #isExpression>

	| msg |
	msg := SBStMessageSend new.
	self block sandblockEditor
		do: (SBWrapCommand new
			outer: msg;
			inner: self block;
			shouldMergeWithNext: true;
			wrap: [:outer :inner | outer receiver: (self block newNullBlock label: 'rcvr') selector: '' arguments: {inner}];
			yourself);
		startInput: msg receiver at: 0 replacingContents: false
]

{ #category : #actions }
SBStGrammarHandler >> wrapEachInOptionalVariant [
	<multiSelectAction>
	<actionValidIf: #isSandblock>

	self assert: self block isSelected.
	self block sandblockEditor doMultiSelectionEach: [:selected | 
		self 
			buildEachCommandForSelected: selected 
			callingAlternativesBuilder: #defaultOptionalAlternativesForBlocks:]
]

{ #category : #actions }
SBStGrammarHandler >> wrapEachInVariant [
	<multiSelectAction>
	<actionValidIf: #isSandblock>

	self assert: self block isSelected.
	self block sandblockEditor doMultiSelectionEach: [:selected | 
		self 
			buildEachCommandForSelected: selected 
			callingAlternativesBuilder: #defaultAlternativesForBlocks:]
]

{ #category : #'action helpers' }
SBStGrammarHandler >> wrapInArrayType: aSymbol [

	self assert: self block isSelected.
	self block sandblockEditor multiSelectionIsConsecutive ifFalse: [^ self].
	self block sandblockEditor doMultiSelection: [:selected |
		(selected size = 1 and: [selected first isUnknown])
			ifTrue: [
				SBReplaceCommand new
					target: selected first;
					replacer: (SBStArray new type: aSymbol contents: #())]
			ifFalse: [
				SBWrapConsecutiveCommand new
					outer: SBStArray new;
					targets: selected;
					wrap: [:outer :inner | outer type: aSymbol contents: inner];
					yourself]]
]

{ #category : #actions }
SBStGrammarHandler >> wrapInAssignment [
	<action>
	<actionValidIf: #isExpression>

	| binding |
	binding := SBStName new.
	self block sandblockEditor do: (SBWrapCommand new
		outer: SBStMessageSend new;
		inner: self block;
		wrap: [:outer :inner | outer binding: binding value: inner];
		shouldMergeWithNext: true;
		yourself).
	
	self block sandblockEditor startInput: binding at: 0 replacingContents: true
]

{ #category : #actions }
SBStGrammarHandler >> wrapInBlock [
	<multiSelectAction>
	<actionValidIf: #canAppearInBlockBody>

	self assert: self block isSelected.
	self block sandblockEditor multiSelectionIsConsecutive ifFalse: [^ self].
	self block sandblockEditor doMultiSelection: [:selected |
		(selected size = 1 and: [selected first isUnknown])
			ifTrue: [
				SBReplaceCommand new
					target: selected first;
					replacer: SBStBlockBody new]
			ifFalse: [
				SBWrapConsecutiveCommand new
					outer: SBStBlockBody new;
					targets: selected;
					wrap: [:outer :inner | outer statements: inner];
					yourself]]
]

{ #category : #actions }
SBStGrammarHandler >> wrapInCascade [
	<action>

	(self block ownerSatisfying: [:owner | owner isMessageSend and: [owner isExpression]]) ifNotNil: [:msg | msg wrapInCascade]
]

{ #category : #actions }
SBStGrammarHandler >> wrapInDynamicArray [
	<multiSelectAction>
	<actionValidIf: #isExpression>

	self wrapInArrayType: #dynamic
]

{ #category : #actions }
SBStGrammarHandler >> wrapInLiteralArray [
	<multiSelectAction>
	<actionValidIf: #isExpression>

	self wrapInArrayType: #literal
]

{ #category : #actions }
SBStGrammarHandler >> wrapInMessageSend [
	<action>
	<actionValidIf: #isExpression>

	^ self wrapInMessageSend: ''
]

{ #category : #'action helpers' }
SBStGrammarHandler >> wrapInMessageSend: aString [

	| msg |
	self block isExpression ifFalse: [^ self].
	msg := self class messageSendClass new
		receiver: (self newNullBlock label: 'expr')
		selector: aString
		arguments: (aString numArgs > 0
			ifTrue: [(1 to: aString numArgs) collect: [:i | self block newNullBlock label: 'arg']]
			ifFalse: [#()]).
	self block sandblockEditor do: (SBWrapCommand new
		outer: msg;
		inner: self block;
		shouldMergeWithNext: true;
		wrap: [:outer :inner | outer receiver: inner];
		yourself).
	self block sandblockEditor
		startInput: msg messageParts first
		at: 900000000
		replacingContents: false.
	^ msg
]

{ #category : #actions }
SBStGrammarHandler >> wrapInOptionalVariant [
	<multiSelectAction>
	<actionValidIf: #isSandblock>

	| variant |
	self assert: self block isSelected.
	variant := SBVariant new.
	self block sandblockEditor multiSelectionIsConsecutive ifFalse: [^ self].
	self block sandblockEditor doMultiSelection: [:selected |
		self 
			buildMultiselectCommandOnVariant: variant
			selected: selected
			callingAlternativesBuilder: #defaultOptionalAlternativesForBlocks:].
		
	variant sandblockEditor select: variant nameBlock.
	variant sandblockEditor save: variant containingArtefact tryFixing: true quick: false.
]

{ #category : #actions }
SBStGrammarHandler >> wrapInReturn [
	<action>

	self block containingStatement ifNotNil: [:stmt |
		stmt isReturn ifTrue: [^ self].
		self block sandblockEditor do: (SBWrapCommand new
			outer: SBStReturn new;
			inner: stmt;
			wrap: [:outer :inner | outer expression: inner];
			yourself).
		stmt startInputAtEnd]
]

{ #category : #actions }
SBStGrammarHandler >> wrapInToggledCode [
	<multiSelectAction>
	<actionValidIf: #canAppearInBlockBody>

	| comment |
	self assert: self block isSelected.
	comment := SBToggledCode new.
	self block sandblockEditor multiSelectionIsConsecutive ifFalse: [^ self].
	self block sandblockEditor doMultiSelection: [:selected |
		SBWrapConsecutiveCommand new
			selectAfter: #block;
			outer: comment;
			targets: selected;
			wrap: [:outer :inner | outer comment: '' active: 0 do: {SBStBlockBody new statements: inner}];
			yourself]
]

{ #category : #actions }
SBStGrammarHandler >> wrapInVariant [
	<multiSelectAction>
	<actionValidIf: #isSandblock>

	| variant |
	self assert: self block isSelected.
	variant := SBVariant new.
	self block sandblockEditor multiSelectionIsConsecutive ifFalse: [^ self].
	self block sandblockEditor doMultiSelection: [:selected |
		self 
			buildMultiselectCommandOnVariant: variant
			selected: selected
			callingAlternativesBuilder: #defaultAlternativesForBlocks:].
		
	variant sandblockEditor select: variant nameBlock.
]

{ #category : #actions }
SBStGrammarHandler >> wrapWithExampleWatch [
	<action>
	<actionValidIf: #isExpression>

	self watchWith: SBExampleWatch
]

{ #category : #printing }
SBStGrammarHandler >> writeSourceOn: aStream for: aBlock [

	aBlock writeStSourceOn: aStream
]
