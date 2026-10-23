
import 'package:retail_gpt/models/retail_list_screen/retail_model.dart';
import 'package:retail_gpt/providers/retail_list_screen/trieNode.dart';

class Trie {
  TrieNode root = TrieNode();

  void insert(RetailModel retail) {
    List<String> words = retail.name.toLowerCase().split(' '); // Break name into words
    for (String word in words) {
      TrieNode node = root;
      for (var char in word.split('')) {
        node.children.putIfAbsent(char, () => TrieNode());
        node = node.children[char]!;
      }
      node.retailList.add(retail); // Store retail entry at the last character of each word
    }
  }

  List<RetailModel> search(String query) {
    TrieNode node = root;
    for (var char in query.toLowerCase().split('')) {
      if (!node.children.containsKey(char)) return [];
      node = node.children[char]!;
    }
    return _collectResults(node);
  }

  List<RetailModel> _collectResults(TrieNode node) {
    List<RetailModel> results = [];
    if (node.retailList.isNotEmpty) results.addAll(node.retailList);
    for (var child in node.children.values) {
      results.addAll(_collectResults(child));
    }
    return results.toSet().toList(); // Remove duplicates
  }
}