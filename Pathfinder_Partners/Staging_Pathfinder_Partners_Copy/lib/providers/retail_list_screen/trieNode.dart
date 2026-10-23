import 'package:retail_gpt/models/retail_list_screen/retail_model.dart';

class TrieNode {
  Map<String, TrieNode> children = {};
  List<RetailModel> retailList = [];
}